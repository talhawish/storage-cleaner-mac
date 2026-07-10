import Foundation

enum GitStatusDetector {
    static func detect(at projectRoot: URL, fileManager: FileManager = .default) -> GitStatus {
        let dotGit = projectRoot.appending(path: ".git", directoryHint: .isDirectory)
        guard fileManager.fileExists(atPath: dotGit.path) else {
            return .notARepo
        }

        let hasUncommitted = hasUncommittedChanges(at: projectRoot, fileManager: fileManager)
        let hasUnpushed = hasUnpushedCommits(at: projectRoot, fileManager: fileManager)

        return GitStatus(
            isRepo: true,
            hasUncommittedChanges: hasUncommitted,
            hasUnpushedCommits: hasUnpushed
        )
    }

    // MARK: - Unpushed detection

    private static func hasUnpushedCommits(at projectRoot: URL, fileManager: FileManager) -> Bool {
        let headURL = projectRoot.appending(path: ".git/HEAD")
        guard let headContent = trimmedContents(of: headURL) else { return false }

        let refPrefix = "ref: refs/heads/"
        guard headContent.hasPrefix(refPrefix) else { return false }

        let branch = String(headContent.dropFirst(refPrefix.count))
        let localRefURL = projectRoot.appending(path: ".git/refs/heads/\(branch)")
        guard let localSHA = trimmedContents(of: localRefURL), !localSHA.isEmpty else {
            return false
        }

        let remotesDir = projectRoot.appending(path: ".git/refs/remotes", directoryHint: .isDirectory)
        guard let remotes = try? fileManager.contentsOfDirectory(atPath: remotesDir.path) else {
            return false
        }

        for remote in remotes where !remote.hasPrefix(".") {
            let remoteRefURL = remotesDir.appending(path: "\(remote)/\(branch)")
            guard let remoteSHA = trimmedContents(of: remoteRefURL), !remoteSHA.isEmpty else {
                continue
            }
            if localSHA != remoteSHA { return true }
        }
        return false
    }

    // MARK: - Uncommitted detection

    private static func hasUncommittedChanges(
        at projectRoot: URL,
        fileManager: FileManager
    ) -> Bool {
        guard let index = GitIndexReader.read(at: projectRoot, fileManager: fileManager) else {
            return false
        }

        if index.entries.isEmpty {
            return true
        }

        for entry in index.entries where entry.isModified(relativeTo: projectRoot, fileManager: fileManager) {
            return true
        }

        return false
    }

    private static func trimmedContents(of url: URL) -> String? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Git index reader

private struct GitIndexReader {
    struct Entry {
        let path: String
        let mtime: UInt32
        let size: UInt32

        func isModified(relativeTo root: URL, fileManager: FileManager) -> Bool {
            let fullPath = root.appending(path: path).path
            guard let attrs = try? fileManager.attributesOfItem(atPath: fullPath) else {
                return true
            }
            let diskSize = UInt32(attrs[.size] as? UInt64 ?? 0)
            let diskMtime = UInt32((attrs[.modificationDate] as? Date ?? .distantPast)
                .timeIntervalSince1970)
            return diskSize != size || abs(Int32(diskMtime - mtime)) > 1
        }
    }

    let entries: [Entry]

    static func read(at projectRoot: URL, fileManager: FileManager) -> GitIndexReader? {
        let indexURL = projectRoot.appending(path: ".git/index")
        guard let data = try? Data(contentsOf: indexURL),
              data.count >= 12,
              String(data: data[0..<4], encoding: .ascii) == "DIRC" else {
            return nil
        }

        let version = readUInt32BE(data, at: 4)
        let entryCount = Int(readUInt32BE(data, at: 8))
        guard (2...4).contains(version), entryCount < 100_000 else { return nil }

        if entryCount == 0 {
            return GitIndexReader(entries: [])
        }

        let hashLen = detectHashLength(data, version: version, entryCount: entryCount)
        let headerLen = 40 + hashLen + 2
        let flagsOffset = headerLen - 2

        var entries: [Entry] = []
        var offset = 12

        for _ in 0..<entryCount {
            guard offset + headerLen <= data.count else { break }

            let flags = readUInt16BE(data, at: offset + flagsOffset)
            var nameLength = Int(flags & 0xFFF)
            let hasExtended = (flags & 0x4000) != 0

            if nameLength == 0xFFF {
                nameLength = resolveLongNameLength(
                    data,
                    offset: offset,
                    headerLen: headerLen,
                    hasExtended: hasExtended
                )
            }
            guard nameLength > 0, nameLength < 4096 else { break }

            var pathStart = offset + headerLen
            if hasExtended { pathStart += 2 }

            let paddedLength = ((nameLength + 8) / 8) * 8
            guard pathStart + paddedLength <= data.count else { break }

            let entryMtime = readUInt32BE(data, at: offset + 8)
            let entrySize = readUInt32BE(data, at: offset + 36)

            guard let path = String(
                data: data[pathStart..<pathStart + nameLength],
                encoding: .utf8
            ) else {
                offset = pathStart + paddedLength
                continue
            }

            entries.append(Entry(path: path, mtime: entryMtime, size: entrySize))
            offset = pathStart + paddedLength
        }

        return GitIndexReader(entries: entries)
    }

    private static func detectHashLength(_ data: Data, version: UInt32, entryCount: Int) -> Int {
        let candidates: [(Int, String)] = [(20, "sha1"), (32, "sha256")]
        for (length, _) in candidates
            where validNameLengthAtFirstEntry(data, headerLen: 40 + length + 2, entryCount: entryCount) {
            return length
        }
        return 20
    }

    private static func validNameLengthAtFirstEntry(_ data: Data, headerLen: Int, entryCount: Int) -> Bool {
        guard data.count >= 12 + headerLen else { return false }
        let flagsOffset = headerLen - 2
        let flags = readUInt16BE(data, at: 12 + flagsOffset)
        let nameLen = Int(flags & 0xFFF)
        guard nameLen > 0, nameLen < 4096 else { return false }

        var pathStart = 12 + headerLen
        if (flags & 0x4000) != 0 { pathStart += 2 }
        guard pathStart + nameLen <= data.count else { return false }

        let nameBytes = data[pathStart..<pathStart + nameLen]
        return String(data: nameBytes, encoding: .utf8) != nil
    }

    private static func resolveLongNameLength(
        _ data: Data,
        offset: Int,
        headerLen: Int,
        hasExtended: Bool
    ) -> Int {
        var searchOffset = offset + headerLen
        if hasExtended { searchOffset += 2 }
        var scanned = 0
        while searchOffset + scanned < data.count, data[searchOffset + scanned] != 0 {
            scanned += 1
            if scanned > 4095 { break }
        }
        return min(scanned, 4095)
    }

    private static func readUInt32BE(_ data: Data, at offset: Int) -> UInt32 {
        data[offset..<offset + 4].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.bigEndian
    }

    private static func readUInt16BE(_ data: Data, at offset: Int) -> UInt16 {
        data[offset..<offset + 2].withUnsafeBytes { $0.loadUnaligned(as: UInt16.self) }.bigEndian
    }
}
