import Foundation

enum ScanPreferences {
    static let includeExternalVolumesKey = "includeExternalVolumes"
    static let showReviewItemsKey = "showReviewItems"

    static var includeExternalVolumes: Bool {
        UserDefaults.standard.bool(forKey: includeExternalVolumesKey)
    }

    static func includingExternalVolumes(_ roots: [URL]) -> [URL] {
        guard includeExternalVolumes else { return roots }
        return roots + externalVolumeRoots()
    }

    private static func externalVolumeRoots() -> [URL] {
        let keys: [URLResourceKey] = [
            .volumeIsBrowsableKey,
            .volumeIsInternalKey,
            .volumeIsLocalKey
        ]
        let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) ?? []

        return volumes.filter { volume in
            guard volume.path != "/" else { return false }
            let values = try? volume.resourceValues(forKeys: Set(keys))
            return values?.volumeIsBrowsable == true
                && values?.volumeIsLocal == true
                && values?.volumeIsInternal != true
        }
    }
}
