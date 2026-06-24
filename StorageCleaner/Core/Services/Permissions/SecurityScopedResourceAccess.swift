import Foundation

struct SecurityScopedResourceAccess: @unchecked Sendable {
    private let stopAccessing: @Sendable () -> Void

    init(url: URL, didStartAccessing: Bool) {
        stopAccessing = {
            guard didStartAccessing else { return }
            url.stopAccessingSecurityScopedResource()
        }
    }

    init(accesses: [SecurityScopedResourceAccess]) {
        stopAccessing = {
            for access in accesses.reversed() {
                access.stop()
            }
        }
    }

    init(onStop: @escaping @Sendable () -> Void) {
        stopAccessing = onStop
    }

    func stop() {
        stopAccessing()
    }
}
