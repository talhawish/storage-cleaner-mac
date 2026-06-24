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
        guard let access = permissionHandler.beginHomeFolderAccess() else {
            return CategoryScanResult(
                finding: nil,
                inspectedItemCount: 0,
                message: "Home Folder access is required"
            )
        }

        defer {
            access.stop()
        }

        return await scanner.scan()
    }
}
