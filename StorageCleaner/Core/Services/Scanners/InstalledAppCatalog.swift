import Foundation

/// Dynamic catalog of the apps currently installed on disk. Used by the system-junk scanners to
/// decide whether a folder or `.plist` in `~/Library/...` is "owned" by an installed app or is
/// orphaned residue from a previously-uninstalled app.
///
/// Discovery is *additive* — the catalog is the union of bundle IDs/names extracted from
/// `.app` bundles across the common install roots plus a curated set of Apple system bundle IDs
/// (`DependencyPaths.SystemJunk.appleBundleIDs`) and dev tool IDs (`...alwaysInstalledBundleIDs`)
/// whose `.app` is hidden inside the macOS bundle and would otherwise be missed.
///
/// The catalog is built on demand and cached for the lifetime of the instance, so multiple
/// scanners in the same scan share one filesystem walk. Re-create the catalog to refresh after
/// installs/uninstalls.
struct InstalledAppCatalog: Sendable {
    /// Lowercased bundle IDs considered "installed". A Library entry whose name matches one of
    /// these is *not* orphaned. Pre-lowercased so `ownsLibraryEntry` is an O(1) Set lookup.
    let bundleIDs: Set<String>
    /// Lowercased folder/file names considered "owned" by an installed app. Used as a fallback
    /// when an app has no usable `CFBundleIdentifier` (older or unsigned bundles).
    let directoryNames: Set<String>

    private static let searchRoots: [URL] = {
        var roots: [URL] = []
        roots.append(URL(fileURLWithPath: "/Applications", isDirectory: true))
        roots.append(URL(fileURLWithPath: "/Applications/Utilities", isDirectory: true))
        let home = UserHomeDirectory.url
        roots.append(home.appending(path: "Applications", directoryHint: .isDirectory))
        return roots
    }()

    init(searchRoots: [URL] = InstalledAppCatalog.searchRoots) {
        var bundleIDs = SystemJunkPaths.appleBundleIDs
        bundleIDs.formUnion(SystemJunkPaths.alwaysInstalledBundleIDs)

        var directoryNames = SystemJunkPaths.reservedSupportDirectoryNames
        directoryNames.formUnion(
            SystemJunkPaths.appleBundleIDs.map { Self.directoryName(for: $0) }
        )
        directoryNames.formUnion(
            SystemJunkPaths.alwaysInstalledBundleIDs.map { Self.directoryName(for: $0) }
        )

        for root in searchRoots {
            Self.collect(from: root, into: &bundleIDs, directoryNames: &directoryNames)
        }

        // Pre-lowercase so ownsLibraryEntry is a constant-time Set lookup.
        self.bundleIDs = Set(bundleIDs.lazy.map { $0.lowercased() })
        self.directoryNames = Set(directoryNames.lazy.map { $0.lowercased() })
    }

    /// `true` if the catalog has a bundle ID or directory name that matches `entryName` (case
    /// insensitive). The match is intentionally loose: Library entry names are case-insensitive
    /// on macOS and vendors are inconsistent about which key they use.
    func ownsLibraryEntry(named entryName: String) -> Bool {
        guard !entryName.isEmpty else { return false }
        let lower = entryName.lowercased()
        return bundleIDs.contains(lower) || directoryNames.contains(lower)
    }

    // MARK: - Collection

    private static func collect(
        from root: URL,
        into bundleIDs: inout Set<String>,
        directoryNames: inout Set<String>
    ) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: root.path) else { return }
        let candidates: [URL]
        do {
            candidates = try fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            return
        }

        for candidate in candidates {
            guard (try? candidate.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            guard candidate.pathExtension.lowercased() == "app" else { continue }

            if let identifier = bundleIdentifier(in: candidate), !identifier.isEmpty {
                bundleIDs.insert(identifier)
                directoryNames.insert(directoryName(for: identifier))
            }
            if let name = displayName(in: candidate), !name.isEmpty {
                directoryNames.insert(name)
            }
        }
    }

    private static func bundleIdentifier(in appBundle: URL) -> String? {
        let plistURL = appBundle.appending(path: "Contents/Info.plist")
        return stringValue(in: plistURL, key: "CFBundleIdentifier")
    }

    private static func displayName(in appBundle: URL) -> String? {
        let plistURL = appBundle.appending(path: "Contents/Info.plist")
        return stringValue(in: plistURL, key: "CFBundleName")
    }

    private static func stringValue(in plistURL: URL, key: String) -> String? {
        guard let data = try? Data(contentsOf: plistURL) else { return nil }
        guard let value = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) else {
            return nil
        }
        return (value as? [String: Any])?[key] as? String
    }

    /// Project a bundle ID to the directory name the matching app would create in
    /// `~/Library/Application Support`. Most apps use the last path component of the bundle ID
    /// (e.g. `com.example.MyApp` → `MyApp`); some use the full ID verbatim. We store both so
    /// either style matches.
    static func directoryName(for bundleID: String) -> String {
        if let last = bundleID.split(separator: ".").last {
            return String(last)
        }
        return bundleID
    }
}
