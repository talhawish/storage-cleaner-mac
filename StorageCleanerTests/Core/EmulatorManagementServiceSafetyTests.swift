import Foundation
import XCTest
@testable import StorageCleaner

/// Regression coverage for the destructive ordering and safety gates around CoreSimulator data.
final class EmulatorManagementServiceSafetyTests: XCTestCase {
    func testBootedSimulatorDeviceIsNotRemovable() async throws {
        let udid = "A01F28DA-DDAC-446E-B66B-8F7D47A7FDF0"
        let recorder = SafetyRecorder()
        let service = makeSafetyService(
            recorder: recorder,
            devicesJSON: simulatorDevicesJSON(udid: udid, state: "Booted")
        )

        let images = await service.discover()
        let simulator = try XCTUnwrap(images.first { $0.platform == .simulatorDevices })

        XCTAssertFalse(simulator.isRemovable, "Booted devices must be shut down before deletion")
        let result = await service.remove([simulator])

        XCTAssertEqual(result.removedCount, 0)
        XCTAssertFalse(recorder.commands.contains(["simctl", "delete", udid]))
    }

    func testRemovesSimulatorDevicesBeforeTheirRuntime() async {
        let runtime = EmulatorImage(
            id: "runtime-id",
            platform: .appleSimulator,
            title: "iOS 26.5",
            versionLabel: "26.5",
            key: VersionKey.parse("26.5"),
            bytes: 8_000_000_000,
            detail: "Build 23F77",
            removal: .simctlRuntime(identifier: "runtime-id"),
            isRemovable: true,
            lastUsed: nil
        )
        let simulator = EmulatorImage(
            id: "device-id",
            platform: .simulatorDevices,
            title: "iPhone 17 Pro",
            versionLabel: "iOS 26.5",
            key: VersionKey.parse("26.5"),
            bytes: 1_000_000,
            detail: "Runtime: iOS 26.5",
            removal: .simctlDevice(udid: "device-id"),
            isRemovable: true,
            lastUsed: nil
        )
        let recorder = SafetyRecorder()
        let service = makeSafetyService(recorder: recorder, devicesJSON: "{\"devices\":{}}")

        let result = await service.remove([runtime, simulator])

        XCTAssertTrue(result.failures.isEmpty)
        XCTAssertEqual(
            recorder.commands,
            [
                ["simctl", "delete", "device-id"],
                ["simctl", "runtime", "delete", "runtime-id"]
            ]
        )
    }

    func testUnavailableSimulatorDeviceIsIdentifiedInDetails() async throws {
        let udid = "A01F28DA-DDAC-446E-B66B-8F7D47A7FDF0"
        let service = makeSafetyService(
            recorder: SafetyRecorder(),
            devicesJSON: simulatorDevicesJSON(
                udid: udid,
                isAvailable: false,
                availabilityError: "runtime profile not found"
            )
        )

        let images = await service.discover()
        let simulator = try XCTUnwrap(images.first { $0.platform == .simulatorDevices })

        XCTAssertTrue(simulator.detail.contains("Unavailable"))
        XCTAssertTrue(simulator.detail.contains("runtime profile not found"))
        XCTAssertTrue(simulator.isRemovable, "Unavailable devices are safe simctl delete candidates")
    }
}

private final class SafetyRecorder: @unchecked Sendable {
    var commands: [[String]] = []
}

private func makeSafetyService(
    recorder: SafetyRecorder,
    devicesJSON: String
) -> EmulatorManagementService {
    EmulatorManagementService(
        runCommand: { _, arguments in
            recorder.commands.append(arguments)
            if arguments == ["simctl", "runtime", "list", "-j"] {
                return .init(exitCode: 0, output: "{}")
            }
            if arguments == ["simctl", "list", "devices", "-j"] {
                return .init(exitCode: 0, output: devicesJSON)
            }
            return .init(exitCode: 0, output: "")
        },
        locateXcrun: { URL(fileURLWithPath: "/usr/bin/xcrun") },
        androidSystemImagesRoot: { nil },
        appleDeviceSupportRoots: { [] },
        readDeviceSupportVersion: { _ in nil },
        simulatorDevicesRoot: { nil },
        measure: { _ in 0 },
        trashItem: { _ in }
    )
}

private func simulatorDevicesJSON(
    udid: String,
    state: String = "Shutdown",
    isAvailable: Bool = true,
    availabilityError: String? = nil
) -> String {
    let availabilityErrorField = availabilityError.map {
        ",\n            \"availabilityError\": \"\($0)\""
    } ?? ""
    return """
    {
      "devices": {
        "com.apple.CoreSimulator.SimRuntime.iOS-26-5": [
          {
            "name": "iPhone 17 Pro",
            "udid": "\(udid)",
            "state": "\(state)",
            "isAvailable": \(isAvailable)\(availabilityErrorField),
            "dataPath": "/Users/test/Library/Developer/CoreSimulator/Devices/\(udid)/data",
            "dataPathSize": 16000000
          }
        ]
      }
    }
    """
}
