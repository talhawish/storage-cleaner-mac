import Foundation

enum PathSafetyComponents {
    static func relevantComponents(for url: URL) -> Set<String> {
        let standardizedURL = url.standardizedFileURL
        let path = standardizedURL.path
        let temporaryPath = FileManager.default.temporaryDirectory.standardizedFileURL.path

        if path.hasPrefix(temporaryPath + "/") {
            let relativePath = String(path.dropFirst(temporaryPath.count + 1))
            return Set(relativePath.split(separator: "/").map(String.init))
        }

        return Set(standardizedURL.pathComponents)
    }
}
