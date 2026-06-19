import Foundation
import XCTest
@testable import StorageCleaner

final class EmulatorManagementServiceTests: XCTestCase {
    /// Records the side effects the service performs so tests can assert on them.
    private final class Recorder: @unchecked Sendable {
        var commands: [[String]] = []
        var trashed: [URL] = []
    }

    private var root: URL!

    /// Two runtimes in the real `simctl runtime list -j` shape: a deletable iOS 26.5 and a
    /// non-deletable iOS 18.0 (e.g. bundled / in use).
    private let simctlJSON = """
    {
      "51B20344-C70D-4CBF-96FE-AD72DE64D881" : {
        "build" : "23F77",
        "deletable" : true,
        "identifier" : "51B20344-C70D-4CBF-96FE-AD72DE64D881",
        "lastUsedAt" : "2026-06-19T01:45:20Z",
        "platformIdentifier" : "com.apple.platform.iphonesimulator",
        "runtimeIdentifier" : "com.apple.CoreSimulator.SimRuntime.iOS-26-5",
        "sizeBytes" : 8494282293,
        "state" : "Ready",
        "version" : "26.5"
      },
      "A1111111-0000-0000-0000-000000000000" : {
        "build" : "22A000",
        "deletable" : false,
        "identifier" : "A1111111-0000-0000-0000-000000000000",
        "platformIdentifier" : "com.apple.platform.iphonesimulator",
        "runtimeIdentifier" : "com.apple.CoreSimulator.SimRuntime.iOS-18-0",
        "sizeBytes" : 7000000000,
        "state" : "Ready",
        "version" : "18.0"
      }
    }
    """

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func makeAndroidImage() throws -> URL {
        let abi = root.appendingPathComponent("system-images/android-36/google_apis/arm64-v8a", isDirectory: true)
        try FileManager.default.createDirectory(at: abi, withIntermediateDirectories: true)
        try Data(count: 4096).write(to: abi.appendingPathComponent("system.img"))
        return abi
    }

    private func makeService(recorder: Recorder, androidRoot: URL?) -> EmulatorManagementService {
        let json = simctlJSON
        return EmulatorManagementService(
            runCommand: { _, arguments in
                recorder.commands.append(arguments)
                if arguments.contains("list") {
                    return .init(exitCode: 0, output: json)
                }
                return .init(exitCode: 0, output: "")
            },
            locateXcrun: { URL(fileURLWithPath: "/usr/bin/xcrun") },
            androidSystemImagesRoot: { androidRoot },
            measure: { _ in 4096 },
            trashItem: { recorder.trashed.append($0) }
        )
    }

    // MARK: - Discovery

    func testDiscoversAppleRuntimesAndAndroidImagesSortedNewestFirst() async throws {
        let abi = try makeAndroidImage()
        let service = makeService(recorder: Recorder(), androidRoot: root.appendingPathComponent("system-images"))

        let images = await service.discover()

        // Apple section comes first, newest runtime first.
        let apple = images.filter { $0.platform == .appleSimulator }
        XCTAssertEqual(apple.map(\.versionLabel), ["26.5", "18.0"])

        let newest = try XCTUnwrap(apple.first)
        XCTAssertEqual(newest.title, "iOS 26.5")
        XCTAssertEqual(newest.bytes, 8_494_282_293)
        XCTAssertTrue(newest.isRemovable)
        XCTAssertEqual(newest.removal, .simctlRuntime(identifier: "51B20344-C70D-4CBF-96FE-AD72DE64D881"))

        let oldNonDeletable = try XCTUnwrap(apple.last)
        XCTAssertFalse(oldNonDeletable.isRemovable, "non-deletable runtimes must not be removable")

        let android = try XCTUnwrap(images.first { $0.platform == .androidEmulator })
        XCTAssertTrue(android.title.contains("API 36"))
        guard case let .trashDirectory(url) = android.removal else {
            return XCTFail("Android image should remove via Trash")
        }
        XCTAssertEqual(url.resolvingSymlinksInPath(), abi.resolvingSymlinksInPath())
    }

    func testMeasuringAndroidSizesFillsInBytesAndLeavesAppleUntouched() async throws {
        _ = try makeAndroidImage()
        let service = makeService(recorder: Recorder(), androidRoot: root.appendingPathComponent("system-images"))

        let measured = service.measuringAndroidSizes(in: await service.discover())
        let android = try XCTUnwrap(measured.first { $0.platform == .androidEmulator })
        XCTAssertEqual(android.bytes, 4096)
        let apple = try XCTUnwrap(measured.first { $0.platform == .appleSimulator })
        XCTAssertEqual(apple.bytes, 8_494_282_293, "Apple sizes come from simctl, not re-measured")
    }

    func testNoAndroidRootYieldsOnlyAppleImages() async {
        let service = makeService(recorder: Recorder(), androidRoot: nil)
        let images = await service.discover()
        XCTAssertTrue(images.allSatisfy { $0.platform == .appleSimulator })
        XCTAssertEqual(images.count, 2)
    }

    // MARK: - Removal

    func testRemoveUsesSimctlForAppleAndTrashForAndroid() async throws {
        let abi = try makeAndroidImage()
        let recorder = Recorder()
        let service = makeService(recorder: recorder, androidRoot: root.appendingPathComponent("system-images"))
        let images = await service.discover()

        let appleNewest = try XCTUnwrap(images.first { $0.id == "51B20344-C70D-4CBF-96FE-AD72DE64D881" })
        let android = try XCTUnwrap(images.first { $0.platform == .androidEmulator })

        let result = await service.remove([appleNewest, android])

        XCTAssertTrue(recorder.commands.contains(["simctl", "runtime", "delete", appleNewest.id]))
        XCTAssertEqual(
            recorder.trashed.map { $0.resolvingSymlinksInPath() },
            [abi.resolvingSymlinksInPath()]
        )
        XCTAssertEqual(result.removedCount, 2)
        XCTAssertEqual(result.totalBytesReclaimed, 8_494_282_293 + 4096)
        XCTAssertTrue(result.failures.isEmpty)
    }

    func testRemoveSkipsNonRemovableRuntimes() async throws {
        let recorder = Recorder()
        let service = makeService(recorder: recorder, androidRoot: nil)
        let images = await service.discover()
        let nonRemovable = try XCTUnwrap(images.first { !$0.isRemovable })

        let result = await service.remove([nonRemovable])

        XCTAssertEqual(result.removedCount, 0)
        XCTAssertFalse(recorder.commands.contains { $0.contains("delete") })
    }

    func testFailedSimctlDeleteIsReportedWithoutReclaim() async throws {
        let recorder = Recorder()
        let json = simctlJSON
        let service = EmulatorManagementService(
            runCommand: { _, arguments in
                recorder.commands.append(arguments)
                if arguments.contains("list") { return .init(exitCode: 0, output: json) }
                return .init(exitCode: 1, output: "Unable to delete: runtime is in use")
            },
            locateXcrun: { URL(fileURLWithPath: "/usr/bin/xcrun") },
            androidSystemImagesRoot: { nil },
            measure: { _ in 0 },
            trashItem: { recorder.trashed.append($0) }
        )
        let images = await service.discover()
        let removable = try XCTUnwrap(images.first(where: \.isRemovable))

        let result = await service.remove([removable])

        XCTAssertEqual(result.removedCount, 0)
        XCTAssertEqual(result.totalBytesReclaimed, 0)
        XCTAssertEqual(result.failures.first?.id, removable.id)
    }
}
