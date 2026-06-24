import Foundation
import XCTest
@testable import StorageCleaner

final class SystemProcessExecutorTests: XCTestCase {
    func testRunDrainsLargeOutputStreamsBeforeProcessExit() async throws {
        let executor = SystemProcessExecutor()
        let bytesPerStream = 160 * 1_024
        let script = """
        chunk=$(printf '%*s' 1024 '' | tr ' ' o)
        i=0
        while [ $i -lt 160 ]; do
          printf "%s" "$chunk"
          i=$((i + 1))
        done
        chunk=$(printf '%*s' 1024 '' | tr ' ' e)
        i=0
        while [ $i -lt 160 ]; do
          printf "%s" "$chunk" >&2
          i=$((i + 1))
        done
        """

        let result = try await executor.run(
            executable: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", script]
        )

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.standardOutput.count, bytesPerStream)
        XCTAssertEqual(result.standardError.count, bytesPerStream)
    }
}
