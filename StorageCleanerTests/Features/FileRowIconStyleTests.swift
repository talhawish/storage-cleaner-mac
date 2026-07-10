import XCTest
@testable import StorageCleaner

final class FileRowIconStyleTests: XCTestCase {
    func testIosDeviceSupportUsesDeviceIconForPackFolders() {
        let pack = URL(
            fileURLWithPath: "/Users/test/Library/Developer/Xcode/iOS DeviceSupport/iPhone15,3 26.5 (23F77)",
            isDirectory: true
        )

        XCTAssertEqual(FileRowIconStyle.symbol(for: pack, kind: .iosDeviceSupport), "iphone")
    }

    func testGenericDirectoriesStillUseFolderIcon() {
        let folder = URL(fileURLWithPath: "/Users/test/Downloads/Archive", isDirectory: true)

        XCTAssertEqual(FileRowIconStyle.symbol(for: folder, kind: .installerLeftovers), "folder.fill")
    }

    func testFileExtensionFallbackStillAppliesWithoutKindOverride() {
        let installer = URL(fileURLWithPath: "/Users/test/Downloads/Xcode.dmg")

        XCTAssertEqual(FileRowIconStyle.symbol(for: installer, kind: .installerLeftovers), "opticaldisc.fill")
    }
}
