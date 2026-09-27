import Foundation

/// Safety boundary for paths macOS owns or protects independently of ordinary Home-folder access.
/// These locations may be readable enough to inventory while still rejecting removal, and they
/// can contain live state for app extensions or the operating system. They are never cleanup
/// candidates; this policy is shared by discovery and deletion as defense in depth.
enum SystemJunkProtectionPolicy {
    static let protectedRoots: [URL] = [
        SystemJunkPaths.containers,
        SystemJunkPaths.groupContainers
    ]

    static func protects(_ url: URL) -> Bool {
        let candidateComponents = url.standardizedFileURL.pathComponents
        // A sandboxed process receives an app-owned temporary directory inside its own container.
        // It is safe to mutate and is also where Xcode-hosted filesystem tests create fixtures.
        let temporaryComponents = FileManager.default.temporaryDirectory.standardizedFileURL.pathComponents
        if contains(candidateComponents, in: temporaryComponents) {
            return false
        }

        if protectedRoots.contains(where: { root in
            let rootComponents = root.standardizedFileURL.pathComponents
            return contains(candidateComponents, in: rootComponents)
        }) {
            return true
        }

        let standardized = url.standardizedFileURL
        let parentName = standardized.deletingLastPathComponent().lastPathComponent
        if parentName == "Application Support" || parentName == "Caches" {
            let name = standardized.lastPathComponent
            let lower = name.lowercased()
            if SystemJunkPaths.reservedSupportDirectoryNames.contains(where: {
                $0.caseInsensitiveCompare(name) == .orderedSame
            })
                || lower == "com.apple"
                || lower.hasPrefix("com.apple.")
                || lower.contains(".com.apple.")
                || lower == "apple"
                || lower.hasPrefix("apple.") {
                return true
            }
        }

        return false
    }

    private static func contains(_ candidate: [String], in root: [String]) -> Bool {
        guard candidate.count >= root.count else { return false }
        return zip(candidate, root).allSatisfy { $0 == $1 }
    }
}
