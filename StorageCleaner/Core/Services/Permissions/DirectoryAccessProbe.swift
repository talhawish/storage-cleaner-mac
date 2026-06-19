import Foundation

/// Determines whether a directory can actually be enumerated — the only reliable signal for
/// macOS TCC / Full Disk Access.
///
/// `FileManager.isReadableFile(atPath:)` inspects POSIX permissions only. TCC-protected folders
/// (Desktop, Downloads, Documents, …) stay POSIX-readable for their owner even when the system
/// denies the app access, so `isReadableFile` reports them as readable and a permission gate built
/// on it never fires. Opening the directory triggers the real TCC check and surfaces the denial as
/// `EPERM`, which is what we classify here.
///
/// The probe opens a single directory handle (no full enumeration), so it is O(1) per folder and
/// cheap enough to run on the main actor.
enum DirectoryAccessProbe {
    static func state(of url: URL) -> StoragePermissionState {
        url.withUnsafeFileSystemRepresentation { pointer in
            guard let pointer else { return .missing }

            errno = 0
            guard let handle = opendir(pointer) else {
                return switch errno {
                case ENOENT, ENOTDIR: .missing
                default: .denied // EPERM (TCC) / EACCES (POSIX) and anything else we cannot read.
                }
            }

            closedir(handle)
            return .accessible
        }
    }
}
