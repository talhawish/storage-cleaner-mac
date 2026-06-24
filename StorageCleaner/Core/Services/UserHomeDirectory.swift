import Darwin
import Foundation

enum UserHomeDirectory {
    static var url: URL {
        URL(fileURLWithPath: path, isDirectory: true)
    }

    static var path: String {
        if let passwordRecord = getpwuid(getuid()),
           let directory = passwordRecord.pointee.pw_dir {
            return String(cString: directory)
        }

        return NSHomeDirectory()
    }

    static func expandingTilde(in path: String) -> String {
        if path == "~" {
            return Self.path
        }

        if path.hasPrefix("~/") {
            let relativePath = String(path.dropFirst(2))
            return url.appending(path: relativePath, directoryHint: .inferFromPath).path
        }

        return NSString(string: path).expandingTildeInPath
    }
}
