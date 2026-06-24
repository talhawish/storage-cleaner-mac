import Foundation

struct SecurityScopedResourceAccess: @unchecked Sendable {
    private let stopAccessing: @Sendable () -> Void

    init(url: URL, didStartAccessing: Bool) {
        stopAccessing = {
            guard didStartAccessing else { return }
            url.stopAccessingSecurityScopedResource()
        }
    }

    func stop() {
        stopAccessing()
    }
}
