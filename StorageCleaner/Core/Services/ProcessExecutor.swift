import Foundation

/// The result of running a subprocess to completion. Captures both streams so
/// failures can be surfaced in confirmation messages instead of generic
/// "compression failed" placeholders.
struct ProcessRunResult: Equatable, Sendable {
    /// Process exit code. `0` conventionally means success.
    let exitCode: Int32
    /// Bytes written by the process to its standard output stream.
    let standardOutput: Data
    /// Bytes written by the process to its standard error stream.
    let standardError: Data

    var standardErrorText: String {
        String(data: standardError, encoding: .utf8) ?? ""
    }
}

/// An error thrown when a subprocess exits non-zero or cannot be launched.
struct ProcessRunError: Error, Equatable, Sendable {
    let executable: String
    let arguments: [String]
    let exitCode: Int32
    let standardError: Data

    var standardErrorText: String {
        String(data: standardError, encoding: .utf8) ?? ""
    }
}

/// Abstraction over spawning a subprocess and collecting its result. Production
/// code uses `DittoProcessExecutor`; tests inject a fake to drive the success
/// and failure paths without touching the real filesystem compression tool.
protocol ProcessExecuting: Sendable {
    func run(executable: URL, arguments: [String]) async throws -> ProcessRunResult
}

/// Runs a subprocess and collects both output streams while the process is
/// still executing so a verbose child cannot block on a full pipe buffer.
struct SystemProcessExecutor: ProcessExecuting {
    func run(executable: URL, arguments: [String]) async throws -> ProcessRunResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            let stdout = LockedDataBuffer()
            let stderr = LockedDataBuffer()
            let state = RunningProcessState(
                process: process,
                stdoutPipe: stdoutPipe,
                stderrPipe: stderrPipe,
                stdout: stdout,
                stderr: stderr
            )

            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                stdout.append(handle.availableData)
            }
            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                stderr.append(handle.availableData)
            }
            process.terminationHandler = { finishedProcess in
                state.closePipeHandlers()
                state.drainRemainingPipeData()
                state.finish(
                    executable: executable,
                    arguments: arguments,
                    terminationStatus: finishedProcess.terminationStatus,
                    terminationReason: finishedProcess.terminationReason,
                    continuation: continuation
                )
            }

            do {
                try process.run()
            } catch {
                state.closePipeHandlers()
                continuation.resume(throwing: error)
            }
        }
    }
}

private final class RunningProcessState: @unchecked Sendable {
    private let process: Process
    private let stdoutPipe: Pipe
    private let stderrPipe: Pipe
    private let stdout: LockedDataBuffer
    private let stderr: LockedDataBuffer

    init(
        process: Process,
        stdoutPipe: Pipe,
        stderrPipe: Pipe,
        stdout: LockedDataBuffer,
        stderr: LockedDataBuffer
    ) {
        self.process = process
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe
        self.stdout = stdout
        self.stderr = stderr
    }

    func closePipeHandlers() {
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        process.terminationHandler = nil
    }

    func drainRemainingPipeData() {
        stdout.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
        stderr.append(stderrPipe.fileHandleForReading.readDataToEndOfFile())
    }

    func finish(
        executable: URL,
        arguments: [String],
        terminationStatus: Int32,
        terminationReason: Process.TerminationReason,
        continuation: CheckedContinuation<ProcessRunResult, any Error>
    ) {
        let outData = stdout.data()
        let errData = stderr.data()
        if terminationReason == .uncaughtSignal {
            continuation.resume(
                throwing: ProcessRunError(
                    executable: executable.path,
                    arguments: arguments,
                    exitCode: terminationStatus,
                    standardError: errData
                )
            )
            return
        }

        continuation.resume(
            returning: ProcessRunResult(
                exitCode: terminationStatus,
                standardOutput: outData,
                standardError: errData
            )
        )
    }
}

private final class LockedDataBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.withLock {
            storage.append(data)
        }
    }

    func data() -> Data {
        lock.withLock { storage }
    }
}

/// Production executor that wraps `ditto` to create a zip archive of a source
/// directory. `ditto -c -k --sequesterRsrc --keepParent <src> <dst.zip>` is
/// what Finder uses for "Compress", and is the only macOS-native way that
/// preserves extended attributes and resource forks.
struct DittoProcessExecutor {
    let underlying: any ProcessExecuting

    init(underlying: any ProcessExecuting = SystemProcessExecutor()) {
        self.underlying = underlying
    }

    /// Compresses `source` into `destination`. `destination` is created
    /// (overwriting any existing file) and the parent directory must exist.
    func compressDirectory(_ source: URL, to destination: URL) async throws {
        let dittoURL = URL(fileURLWithPath: "/usr/bin/ditto")
        let arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", source.path, destination.path]
        let result = try await underlying.run(executable: dittoURL, arguments: arguments)
        guard result.exitCode == 0 else {
            throw ProcessRunError(
                executable: dittoURL.path,
                arguments: arguments,
                exitCode: result.exitCode,
                standardError: result.standardError
            )
        }
    }

    /// Verifies that `archive` is a well-formed zip. Uses `unzip -t` which
    /// tests every entry's CRC without extracting.
    func verifyArchive(_ archive: URL) async throws {
        let unzipURL = URL(fileURLWithPath: "/usr/bin/unzip")
        let arguments = ["-t", archive.path]
        let result = try await underlying.run(executable: unzipURL, arguments: arguments)
        guard result.exitCode == 0 else {
            throw ProcessRunError(
                executable: unzipURL.path,
                arguments: arguments,
                exitCode: result.exitCode,
                standardError: result.standardError
            )
        }
    }
}
