import Foundation

struct SecurityScopedCategoryScanner: StorageCategoryScanning {
    let kind: StorageFindingKind
    let title: String

    private let scanner: any StorageCategoryScanning
    private let permissionHandler: any StoragePermissionHandling

    init(scanner: any StorageCategoryScanning, permissionHandler: any StoragePermissionHandling) {
        self.kind = scanner.kind
        self.title = scanner.title
        self.scanner = scanner
        self.permissionHandler = permissionHandler
    }

    func scan() async -> CategoryScanResult {
        // The shared helper calls `beginHomeFolderAccess()` exactly once and
        // hands the access token to the body. The dashboard's permission UX
        // (a specific "Home Folder access is required" finding) is preserved
        // by branching on the token before running the inner scanner —
        // otherwise the scan would silently return an empty finding on a
        // sandboxed build without a grant.
        await permissionHandler.withHomeFolderAccess { access in
            guard access != nil else {
                return CategoryScanResult(
                    finding: nil,
                    inspectedItemCount: 0,
                    message: "Home Folder access is required"
                )
            }
            return await scanner.scan()
        }
    }
}
