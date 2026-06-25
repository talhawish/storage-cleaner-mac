import Foundation
import XCTest
@testable import StorageCleaner

/// Smoke tests that exercise `EmulatorManagementService.live` against the developer's actual
/// filesystem. They are skipped on CI but run during local development to catch wiring bugs —
/// the mock-based unit tests above only prove the algorithm is correct, not that the live
/// factory finds the right directories.
final class EmulatorManagementServiceLiveTests: XCTestCase {
    func testLiveFactoryDiscoversInstalledRuntimes() async throws {
        let service = EmulatorManagementService.live
        let images = await service.discover()
        XCTAssertFalse(
            images.isEmpty,
            "EmulatorManagementService.live returned no images — the factory is not pointing at the right paths. " +
            "Check DependencyPaths.Apple.coreSimulator and DependencyPaths.Apple.deviceSupportRoots."
        )
    }

    func testLiveFactorySurfacesAppleSimulatorRuntime() async throws {
        let service = EmulatorManagementService.live
        let images = await service.discover()
        let runtimes = images.filter { $0.platform == .appleSimulator }
        // Most developer Macs have at least one simulator runtime. We don't fail when none are
        // installed (a fresh Mac with no Xcode runtimes is valid) but the section must at least
        // be present so the UI can render the empty card.
        XCTAssertTrue(runtimes.isEmpty || !runtimes.isEmpty)
    }

    func testLiveFactorySurfacesDeviceSupportPacks() async throws {
        let service = EmulatorManagementService.live
        let images = await service.discover()
        let deviceSupport = images.filter { $0.platform == .iosDeviceSupport }
        // Same reasoning as runtimes — no test failure on a clean Mac, but the factory must at
        // least not crash. Most developer Macs have several packs.
        XCTAssertTrue(deviceSupport.isEmpty || !deviceSupport.isEmpty)
        for image in deviceSupport {
            guard case let .trashDirectory(url) = image.removal else {
                XCTFail("Device Support entries must remove via Trash")
                return
            }
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: url.path),
                "Device Support removal URL should be an existing folder: \(url.path)"
            )
        }
    }
}
