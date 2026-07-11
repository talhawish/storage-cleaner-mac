import Foundation
import XCTest
@testable import StorageCleaner

/// Two runtimes in the real `simctl runtime list -j` shape: a deletable iOS 26.5 and a
/// non-deletable iOS 18.0 (e.g. bundled / in use).
private let emulatorSimctlRuntimesJSON = """
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

private let emptyEmulatorDevicesJSON = #"{"devices":{}}"#

/// Records the side effects the service performs so tests can assert on them.
private final class Recorder: @unchecked Sendable {
    var commands: [[String]] = []
    var trashed: [URL] = []
}

final class EmulatorManagementServiceTests: XCTestCase {
    private var root: URL!

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

    private func makeDeviceSupportFolder(
        name: String,
        version: String? = nil,
        bytes: Int = 32_768
    ) throws -> URL {
        let folder = root
            .appendingPathComponent("device-support", isDirectory: true)
            .appendingPathComponent("iOS DeviceSupport", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(count: bytes).write(to: folder.appendingPathComponent("Symbols.dSYM"))
        if let version {
            let plistURL = folder.appendingPathComponent("Info.plist")
            let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0"><dict><key>Version</key><string>\(version)</string></dict></plist>
            """
            try xml.write(to: plistURL, atomically: true, encoding: .utf8)
        }
        return folder
    }

    private func makeSimulatorDevice(
        name: String,
        runtime: String? = "com.apple.CoreSimulator.SimRuntime.iOS-26-5",
        bytes: Int = 1024
    ) throws -> URL {
        let device = root
            .appendingPathComponent("simulator-devices", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: device, withIntermediateDirectories: true)
        try Data(count: bytes).write(to: device.appendingPathComponent("data.bin"))
        if let runtime {
            let plistURL = device.appendingPathComponent("device.plist")
            let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" \
            "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0"><dict><key>name</key><string>iPhone 17 Pro</string>\
            <key>runtime</key><string>\(runtime)</string></dict></plist>
            """
            try xml.write(to: plistURL, atomically: true, encoding: .utf8)
        }
        return device
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

    func testMeasuringRemainingSizesFillsInBytesAndLeavesAppleUntouched() async throws {
        _ = try makeAndroidImage()
        let service = makeService(recorder: Recorder(), androidRoot: root.appendingPathComponent("system-images"))

        let measured = service.measuringRemainingSizes(in: await service.discover())
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

    // MARK: - Apple Device Support

    func testDiscoversDeviceSupportPacksAndGroupsByPlatform() async throws {
        let iosPackA = try makeDeviceSupportFolder(name: "iPhone15,3 26.5 (23F77)", version: "26.5")
        _ = try makeDeviceSupportFolder(name: "iPhone11,6 18.7.8 (22H352)", version: "18.7.8")
        let tvosRoot = root.appendingPathComponent("device-support/tvOS DeviceSupport", isDirectory: true)
        try FileManager.default.createDirectory(at: tvosRoot, withIntermediateDirectories: true)
        let tvosPack = tvosRoot.appendingPathComponent("AppleTV14,1 18.4 (22L123f1)", isDirectory: true)
        try FileManager.default.createDirectory(at: tvosPack, withIntermediateDirectories: true)
        let tvosPlist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict><key>Version</key><string>18.4</string></dict></plist>
        """
        try tvosPlist.write(to: tvosPack.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)

        // The live filter requires each root to already be the platform-specific folder
        // (`iOS DeviceSupport/`, `tvOS DeviceSupport/`, …) — not the parent that contains them all.
        let iosRoot = iosPackA.deletingLastPathComponent()
        let service = makeService(
            recorder: Recorder(),
            androidRoot: nil,
            appleDeviceSupportRoots: [iosRoot, tvosRoot]
        )

        let images = await service.discover()
        let deviceSupport = images.filter { $0.platform == .iosDeviceSupport }
        XCTAssertEqual(deviceSupport.count, 3)

        // Newest first within the same platform.
        let iosPacks = deviceSupport.filter { $0.title.hasPrefix("iOS ") }
        XCTAssertEqual(iosPacks.map(\.versionLabel), ["26.5", "18.7.8"])

        let tvosPackImage = try XCTUnwrap(deviceSupport.first { $0.title.hasPrefix("tvOS ") })
        XCTAssertEqual(tvosPackImage.versionLabel, "18.4")
        XCTAssertTrue(tvosPackImage.title.contains("AppleTV14,1"))
        XCTAssertTrue(tvosPackImage.detail.contains("Build 22L123f1"), "build appears in detail, not title")

        // Removal is the directory itself (Trash), not a simctl handle.
        for image in deviceSupport {
            guard case let .trashDirectory(url) = image.removal else {
                return XCTFail("Device Support entries must remove via Trash")
            }
            XCTAssertTrue(url.lastPathComponent.contains("("), "Removal URL should be the device-version folder")
        }
    }

    func testDeviceSupportUsesPlistVersionWhenFolderNameIsAmbiguous() async throws {
        // Folder name has no version; plist supplies it. The build is still parsed from
        // the folder name's `(...)` suffix.
        let folder = try makeDeviceSupportFolder(
            name: "iPhone16,1 (23A5314b)",
            version: "26.6 beta 2"
        )
        let service = makeService(
            recorder: Recorder(),
            androidRoot: nil,
            appleDeviceSupportRoots: [folder.deletingLastPathComponent()]
        )

        let images = await service.discover()
        let pack = try XCTUnwrap(images.first { $0.platform == .iosDeviceSupport })
        XCTAssertEqual(pack.versionLabel, "26.6 beta 2")
        XCTAssertTrue(pack.title.contains("iPhone16,1"))
        XCTAssertTrue(pack.detail.contains("Build 23A5314b"))
    }

    func testDeviceSupportRemovalTrashesThePack() async throws {
        let folder = try makeDeviceSupportFolder(name: "iPhone15,3 26.5 (23F77)", version: "26.5")
        let recorder = Recorder()
        let service = makeService(
            recorder: recorder,
            androidRoot: nil,
            appleDeviceSupportRoots: [folder.deletingLastPathComponent()]
        )

        let images = await service.discover()
        let pack = try XCTUnwrap(images.first { $0.platform == .iosDeviceSupport })
        let result = await service.remove([pack])

        XCTAssertEqual(result.removedCount, 1)
        XCTAssertEqual(recorder.trashed.map { $0.resolvingSymlinksInPath() }, [folder.resolvingSymlinksInPath()])
    }

    // MARK: - Simulator devices

    func testDiscoversSimulatorDeviceInstancesWithReadableNames() async throws {
        let udid = "A01F28DA-DDAC-446E-B66B-8F7D47A7FDF0"
        let device = try makeSimulatorDevice(name: udid)
        let devicesRoot = device.deletingLastPathComponent()
        let service = makeService(
            recorder: Recorder(),
            androidRoot: nil,
            simulatorDevicesRoot: devicesRoot,
            simulatorDevicesJSON: simulatorDevicesJSON(udid: udid, deviceDirectory: device)
        )

        let images = await service.discover()
        let simulators = images.filter { $0.platform == .simulatorDevices }
        XCTAssertEqual(simulators.count, 1)
        let sim = try XCTUnwrap(simulators.first)
        XCTAssertEqual(sim.id, udid)
        XCTAssertEqual(sim.title, "iPhone 17 Pro")
        XCTAssertEqual(sim.versionLabel, "iOS 26.5")
        XCTAssertTrue(sim.detail.contains("iOS-26-5"))
        XCTAssertEqual(sim.bytes, 9_500_000_000)
        guard case let .simctlDevice(deviceUDID) = sim.removal else {
            return XCTFail("Known simulator devices should remove through simctl")
        }
        XCTAssertEqual(deviceUDID, udid)
    }

    func testOrphanedSimulatorDeviceFallsBackToShortTitle() async throws {
        let device = try makeSimulatorDevice(name: "B1111111-2222-3333-4444-555555555555", runtime: nil)
        let service = makeService(
            recorder: Recorder(),
            androidRoot: nil,
            simulatorDevicesRoot: device.deletingLastPathComponent()
        )

        let images = await service.discover()
        let sim = try XCTUnwrap(images.first { $0.platform == .simulatorDevices })
        XCTAssertEqual(sim.title, "B1111111")
        XCTAssertTrue(sim.detail.contains("Orphaned"))
        guard case let .trashDirectory(url) = sim.removal else {
            return XCTFail("Orphaned simulator device folders should remain Trash-managed")
        }
        XCTAssertEqual(url.resolvingSymlinksInPath(), device.resolvingSymlinksInPath())
    }

    func testKnownSimulatorDeviceRemovalUsesSimctlDelete() async throws {
        let udid = "A01F28DA-DDAC-446E-B66B-8F7D47A7FDF0"
        let device = try makeSimulatorDevice(name: udid)
        let recorder = Recorder()
        let service = makeService(
            recorder: recorder,
            androidRoot: nil,
            simulatorDevicesRoot: device.deletingLastPathComponent(),
            simulatorDevicesJSON: simulatorDevicesJSON(udid: udid, deviceDirectory: device)
        )

        let images = await service.discover()
        let sim = try XCTUnwrap(images.first { $0.platform == .simulatorDevices })
        let result = await service.remove([sim])

        XCTAssertEqual(result.removedCount, 1)
        XCTAssertTrue(recorder.trashed.isEmpty)
        XCTAssertTrue(recorder.commands.contains(["simctl", "delete", udid]))
        XCTAssertEqual(result.totalBytesReclaimed, 9_500_000_000)
    }

    func testOrphanedSimulatorDeviceRemovalTrashesTheDeviceFolder() async throws {
        let device = try makeSimulatorDevice(name: "B1111111-2222-3333-4444-555555555555", runtime: nil)
        let recorder = Recorder()
        let service = makeService(
            recorder: recorder,
            androidRoot: nil,
            simulatorDevicesRoot: device.deletingLastPathComponent()
        )

        let images = await service.discover()
        let sim = try XCTUnwrap(images.first { $0.platform == .simulatorDevices })
        let result = await service.remove([sim])

        XCTAssertEqual(result.removedCount, 1)
        XCTAssertEqual(
            recorder.trashed.map { $0.resolvingSymlinksInPath() },
            [device.resolvingSymlinksInPath()]
        )
        XCTAssertFalse(
            recorder.commands.contains(["simctl", "delete", sim.id]),
            "Only known CoreSimulator devices should remove through simctl."
        )
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
        let service = EmulatorManagementService(
            runCommand: { _, arguments in
                recorder.commands.append(arguments)
                if arguments == ["simctl", "runtime", "list", "-j"] {
                    return .init(exitCode: 0, output: emulatorSimctlRuntimesJSON)
                }
                if arguments == ["simctl", "list", "devices", "-j"] {
                    return .init(exitCode: 0, output: emptyEmulatorDevicesJSON)
                }
                return .init(exitCode: 1, output: "Unable to delete: runtime is in use")
            },
            locateXcrun: { URL(fileURLWithPath: "/usr/bin/xcrun") },
            androidSystemImagesRoot: { nil },
            appleDeviceSupportRoots: { [] },
            readDeviceSupportVersion: { _ in nil },
            simulatorDevicesRoot: { nil },
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

    // MARK: - Helpers

    func testParseDeviceSupportNameHandlesAllShapes() {
        let first = EmulatorManagementService.parseDeviceSupportName("iPhone15,3 26.5 (23F77)")
        XCTAssertEqual(first.deviceSuffix, "iPhone15,3")
        XCTAssertEqual(first.version, "26.5")
        XCTAssertEqual(first.build, "23F77")

        let tvos = EmulatorManagementService.parseDeviceSupportName("AppleTV14,1 18.4 (22L123f1)")
        XCTAssertEqual(tvos.deviceSuffix, "AppleTV14,1")
        XCTAssertEqual(tvos.version, "18.4")
        XCTAssertEqual(tvos.build, "22L123f1")

        let bare = EmulatorManagementService.parseDeviceSupportName("iPhone16,1")
        XCTAssertEqual(bare.deviceSuffix, "iPhone16,1")
        XCTAssertNil(bare.version)
        XCTAssertNil(bare.build)
    }

    func testRuntimeVersionLabelExtractsOSAndVersion() {
        XCTAssertEqual(
            EmulatorManagementService.runtimeVersionLabel(from: "com.apple.CoreSimulator.SimRuntime.iOS-26-4"),
            "iOS 26.4"
        )
        XCTAssertEqual(
            EmulatorManagementService.runtimeVersionLabel(from: "com.apple.CoreSimulator.SimRuntime.tvOS-18-4"),
            "tvOS 18.4"
        )
    }

}

private func simulatorDevicesJSON(udid: String, deviceDirectory: URL) -> String {
    let dataPath = deviceDirectory.appendingPathComponent("data", isDirectory: true).path
    return """
    {
      "devices": {
        "com.apple.CoreSimulator.SimRuntime.iOS-26-5": [
          {
            "name": "iPhone 17 Pro",
            "udid": "\(udid)",
            "state": "Shutdown",
            "isAvailable": true,
            "dataPath": "\(dataPath)",
            "dataPathSize": 9500000000,
            "lastBootedAt": "2026-06-20T10:00:00Z"
          }
        ]
      }
    }
    """
}

private func makeService(
    recorder: Recorder,
    androidRoot: URL?,
    appleDeviceSupportRoots: [URL]? = nil,
    simulatorDevicesRoot: URL? = nil,
    simulatorDevicesJSON: String? = nil
) -> EmulatorManagementService {
    let devicesJSON = simulatorDevicesJSON ?? emptyEmulatorDevicesJSON
    return EmulatorManagementService(
        runCommand: { _, arguments in
            recorder.commands.append(arguments)
            if arguments == ["simctl", "runtime", "list", "-j"] {
                return .init(exitCode: 0, output: emulatorSimctlRuntimesJSON)
            }
            if arguments == ["simctl", "list", "devices", "-j"] {
                return .init(exitCode: 0, output: devicesJSON)
            }
            return .init(exitCode: 0, output: "")
        },
        locateXcrun: { URL(fileURLWithPath: "/usr/bin/xcrun") },
        androidSystemImagesRoot: { androidRoot },
        appleDeviceSupportRoots: { appleDeviceSupportRoots ?? [] },
        readDeviceSupportVersion: { folder in
            let plist = folder.appendingPathComponent("Info.plist")
            guard let data = try? Data(contentsOf: plist),
                  let raw = try? PropertyListSerialization.propertyList(from: data, format: nil),
                  let dict = raw as? [String: Any] else { return nil }
            return dict["Version"] as? String
        },
        simulatorDevicesRoot: { simulatorDevicesRoot },
        measure: { _ in 4096 },
        trashItem: { recorder.trashed.append($0) }
    )
}
