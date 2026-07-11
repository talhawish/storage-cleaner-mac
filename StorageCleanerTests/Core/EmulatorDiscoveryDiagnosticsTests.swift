import Foundation
import XCTest
@testable import StorageCleaner

/// Covers `discoverWithDiagnostics()` — the Emulators screen relies on its
/// `failureMessage` to distinguish "nothing installed" from "the inventory is
/// unreliable" (e.g. a broken `simctl`).
final class EmulatorDiscoveryDiagnosticsTests: XCTestCase {
    /// A failing simctl with the Xcode tooling present is a real failure the
    /// UI must be able to distinguish from "nothing installed".
    func testDiscoverWithDiagnosticsReportsSimctlFailure() async {
        let service = makeService(
            runCommand: { _, _ in .init(exitCode: 1, output: "error: broken CoreSimulator service\n") },
            locateXcrun: { URL(fileURLWithPath: "/usr/bin/xcrun") }
        )

        let discovery = await service.discoverWithDiagnostics()

        XCTAssertTrue(discovery.images.isEmpty)
        XCTAssertEqual(
            discovery.failureMessage,
            "simctl couldn't list simulator runtimes: error: broken CoreSimulator service"
        )
    }

    /// No xcrun means no Xcode tooling — an empty inventory is a true empty,
    /// never a failure.
    func testDiscoverWithDiagnosticsIsCleanWhenXcodeToolingIsAbsent() async {
        let service = makeService(
            runCommand: { _, _ in .init(exitCode: 1, output: "unused") },
            locateXcrun: { nil }
        )

        let discovery = await service.discoverWithDiagnostics()

        XCTAssertTrue(discovery.images.isEmpty)
        XCTAssertNil(discovery.failureMessage)
    }

    private func makeService(
        runCommand: @escaping @Sendable (URL, [String]) async -> EmulatorManagementService.CommandOutput,
        locateXcrun: @escaping @Sendable () -> URL?
    ) -> EmulatorManagementService {
        EmulatorManagementService(
            runCommand: runCommand,
            locateXcrun: locateXcrun,
            androidSystemImagesRoot: { nil },
            appleDeviceSupportRoots: { [] },
            readDeviceSupportVersion: { _ in nil },
            simulatorDevicesRoot: { nil },
            measure: { _ in 0 },
            trashItem: { _ in }
        )
    }
}
