import Darwin
import Foundation

/// Distinguishes a path that disappeared after scanning from a path macOS refused to inspect.
/// Treating every failed existence check as "already gone" can falsely report blocked items as
/// successfully cleaned.
enum FileItemExistence {
    static func attributes(
        at url: URL,
        fileManager: FileManager = .default
    ) throws -> [FileAttributeKey: Any]? {
        do {
            return try fileManager.attributesOfItem(atPath: url.path)
        } catch {
            guard isMissingItemError(error) else { throw error }
            return nil
        }
    }

    static func isMissingItemError(_ error: Error) -> Bool {
        let nsError = error as NSError
        let cocoaMissingCodes = [
            CocoaError.Code.fileNoSuchFile.rawValue,
            CocoaError.Code.fileReadNoSuchFile.rawValue
        ]
        return (nsError.domain == NSCocoaErrorDomain && cocoaMissingCodes.contains(nsError.code))
            || (nsError.domain == NSPOSIXErrorDomain && nsError.code == ENOENT)
    }
}
