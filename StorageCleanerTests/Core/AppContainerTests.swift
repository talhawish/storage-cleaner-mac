import XCTest
@testable import StorageCleaner

final class AppContainerTests: XCTestCase {
    func testDemoContainerEmulatorServiceUsesIsolatedDeterministicInventory() async {
        let container = AppContainer.current(arguments: ["StorageCleaner", "--use-demo-scanner"])

        let images = await container.emulatorService.discover()

        XCTAssertEqual(images.count, 2)
        XCTAssertTrue(images.allSatisfy { $0.trashDirectoryURL?.path.hasPrefix("/tmp/StorageCleanerDemo/") == true })

        let result = await container.emulatorService.remove([images[0]])
        let remainingImages = await container.emulatorService.discover()
        XCTAssertEqual(result.removedIDs, [images[0].id])
        XCTAssertEqual(remainingImages, [images[1]])
    }
}
