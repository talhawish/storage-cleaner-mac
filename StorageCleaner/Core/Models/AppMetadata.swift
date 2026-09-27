import Foundation

enum AppMetadata {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    static var scannerCount: Int {
        StorageFindingKind.allCases.count
    }

    static var versionDisplay: String {
        let currentBuild = build
        guard currentBuild != "—", !currentBuild.isEmpty else { return version }
        return "\(version) (\(currentBuild))"
    }
}
