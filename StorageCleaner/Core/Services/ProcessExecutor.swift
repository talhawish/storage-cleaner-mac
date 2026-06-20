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

/// Runs `/usr/bin/ditto` synchronously on a background thread and collects both
/// output streams. `Process` itself is single-shot and not `Sendable`, so the
/// work is dispatched off the main actor and the result is returned as a value
/// type.
struct SystemProcessExecutor: ProcessExecuting {
    func run(executable: URL, arguments: [String]) async throws -> ProcessRunResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = executable
                process.arguments = arguments

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                process.waitUntilExit()
                let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let result = ProcessRunResult(
                    exitCode: process.terminationStatus,
                    standardOutput: outData,
                    standardError: errData
                )
                if process.terminationReason == .uncaughtSignal {
                    continuation.resume(
                        throwing: ProcessRunError(
                            executable: executable.path,
                            arguments: arguments,
                            exitCode: process.terminationStatus,
                            standardError: errData
                        )
                    )
                    return
                }
                continuation.resume(returning: result)
            }
        }
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
