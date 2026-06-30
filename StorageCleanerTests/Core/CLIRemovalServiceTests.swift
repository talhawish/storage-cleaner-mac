import Foundation
import XCTest
@testable import StorageCleaner

final class CLIRemovalServiceTests: XCTestCase {
    private let brew = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
    private let cellarFormula = URL(fileURLWithPath: "/opt/homebrew/Cellar/git", isDirectory: true)
    private let caskApp = URL(fileURLWithPath: "/opt/homebrew/Caskroom/ghostty", isDirectory: true)
    private let versionDir = URL(fileURLWithPath: "/Users/test/.pyenv/versions/3.11.4", isDirectory: true)

    // MARK: - Classification

    func testClassifyIdentifiesCellarFormula() {
        XCTAssertEqual(CLIRemovalService.classify(cellarFormula), .homebrew(name: "git", isCask: false))
    }

    func testClassifyIdentifiesCask() {
        XCTAssertEqual(CLIRemovalService.classify(caskApp), .homebrew(name: "ghostty", isCask: true))
    }

    func testClassifyTreatsOtherPathsAsOther() {
        XCTAssertEqual(CLIRemovalService.classify(versionDir), .other)
    }

    func testClassifyRequiresManualRemovalForSystemJDK() {
        let jdk = URL(fileURLWithPath: "/Library/Java/JavaVirtualMachines/temurin-21.jdk", isDirectory: true)

        guard case .manualRemovalRequired = CLIRemovalService.classify(jdk) else {
            return XCTFail("System JDKs must not be trashed automatically")
        }
    }

    // MARK: - Homebrew uninstall

    func testFormulaIsUninstalledViaBrewAndNotTrashed() async {
        let recorder = Recorder()
        let service = makeService(recorder: recorder)

        let result = await service.remove([cellarFormula])

        XCTAssertEqual(recorder.commands, [["uninstall", "--formula", "git"]])
        XCTAssertTrue(recorder.trashed.isEmpty, "Homebrew kegs must not be trashed directly")
        XCTAssertEqual(result.deletedURLs, [cellarFormula])
        XCTAssertEqual(result.totalBytesReclaimed, 100)
        XCTAssertTrue(result.succeeded)
    }

    func testCaskIsUninstalledWithCaskFlag() async {
        let recorder = Recorder()
        let service = makeService(recorder: recorder)

        _ = await service.remove([caskApp])

        XCTAssertEqual(recorder.commands, [["uninstall", "--cask", "ghostty"]])
    }

    func testFailedBrewUninstallIsReportedAndNothingIsRemoved() async {
        let recorder = Recorder()
        let service = makeService(
            recorder: recorder,
            commandResult: { _, _ in .init(exitCode: 1, output: "Error: git is required by foo\n") }
        )

        let result = await service.remove([cellarFormula])

        XCTAssertTrue(result.deletedURLs.isEmpty)
        XCTAssertEqual(result.totalBytesReclaimed, 0)
        XCTAssertEqual(result.failedCount, 1)
        guard case let CLIRemovalError.homebrewUninstallFailed(name, message)? = result.failedURLs.first?.1 else {
            return XCTFail("Expected homebrewUninstallFailed error")
        }
        XCTAssertEqual(name, "git")
        XCTAssertEqual(message, "Error: git is required by foo")
    }

    func testFallsBackToTrashWhenHomebrewIsMissing() async {
        let recorder = Recorder()
        let service = makeService(recorder: recorder, brew: nil)

        let result = await service.remove([cellarFormula])

        XCTAssertTrue(recorder.commands.isEmpty)
        XCTAssertEqual(recorder.trashed, [cellarFormula])
        XCTAssertEqual(result.deletedURLs, [cellarFormula])
    }

    // MARK: - Non-Homebrew

    func testNonHomebrewItemIsTrashedWithoutBrewOrSweep() async {
        let recorder = Recorder()
        recorder.linkDirectories = [URL(fileURLWithPath: "/opt/homebrew/bin")]
        let service = makeService(recorder: recorder)

        let result = await service.remove([versionDir])

        XCTAssertEqual(recorder.trashed, [versionDir])
        XCTAssertTrue(recorder.commands.isEmpty)
        XCTAssertTrue(recorder.removedSymlinks.isEmpty, "Symlink sweep should only run after a Homebrew removal")
        XCTAssertEqual(result.deletedURLs, [versionDir])
    }

    func testTrashFailureIsReported() async {
        let recorder = Recorder()
        recorder.trashError = CocoaError(.fileWriteNoPermission)
        let service = makeService(recorder: recorder)

        let result = await service.remove([versionDir])

        XCTAssertTrue(result.deletedURLs.isEmpty)
        XCTAssertEqual(result.failedCount, 1)
    }

    func testSystemJDKRemovalReportsManualFailureWithoutTrash() async {
        let jdk = URL(fileURLWithPath: "/Library/Java/JavaVirtualMachines/temurin-21.jdk", isDirectory: true)
        let recorder = Recorder()
        let service = makeService(recorder: recorder)

        let result = await service.remove([jdk])

        XCTAssertTrue(recorder.trashed.isEmpty)
        XCTAssertTrue(result.deletedURLs.isEmpty)
        XCTAssertEqual(result.failedCount, 1)
        guard case CLIRemovalError.manualRemovalRequired? = result.failedURLs.first?.1 else {
            return XCTFail("Expected manualRemovalRequired")
        }
    }

    // MARK: - Broken-symlink sweep

    func testHomebrewRemovalSweepsOnlyDanglingSymlinks() async {
        let binDir = URL(fileURLWithPath: "/opt/homebrew/bin")
        let dangling = binDir.appendingPathComponent("git")
        let healthy = binDir.appendingPathComponent("node")

        let recorder = Recorder()
        recorder.linkDirectories = [binDir]
        recorder.symlinksByDirectory = [binDir: [dangling, healthy]]
        recorder.danglingSymlinks = [dangling]

        let service = makeService(recorder: recorder)
        _ = await service.remove([cellarFormula])

        XCTAssertEqual(recorder.removedSymlinks, [dangling])
        XCTAssertFalse(recorder.removedSymlinks.contains(healthy), "Valid symlinks must be preserved")
    }

    // MARK: - Misc

    func testEmptyInputDoesNothing() async {
        let recorder = Recorder()
        let service = makeService(recorder: recorder)

        let result = await service.remove([])

        XCTAssertTrue(recorder.commands.isEmpty)
        XCTAssertTrue(recorder.trashed.isEmpty)
        XCTAssertEqual(result.totalBytesReclaimed, 0)
    }

    func testReclaimedBytesAreSummedAcrossItems() async {
        let recorder = Recorder()
        let service = makeService(recorder: recorder, sizePerItem: 250)

        let result = await service.remove([cellarFormula, caskApp])

        XCTAssertEqual(result.deletedCount, 2)
        XCTAssertEqual(result.totalBytesReclaimed, 500)
    }

    // MARK: - Node global classification

    func testClassifyDetectsNpmGlobalUnderBrewPrefix() {
        let pkg = URL(fileURLWithPath: "/opt/homebrew/lib/node_modules/firebase-tools", isDirectory: true)
        guard case let .nodeGlobal(plan) = CLIRemovalService.classify(pkg) else {
            return XCTFail("Expected nodeGlobal")
        }
        XCTAssertEqual(plan.packageName, "firebase-tools")
        XCTAssertEqual(plan.arguments, ["uninstall", "-g", "firebase-tools"])
        XCTAssertEqual(plan.toolCandidates.first, URL(fileURLWithPath: "/opt/homebrew/bin/npm"))
        XCTAssertEqual(plan.binDirectory, URL(fileURLWithPath: "/opt/homebrew/bin"))
    }

    func testClassifyHandlesScopedPackageName() {
        let pkg = URL(
            fileURLWithPath: "/Users/me/.nvm/versions/node/v20.0.0/lib/node_modules/@anthropic-ai/claude-code",
            isDirectory: true
        )
        guard case let .nodeGlobal(plan) = CLIRemovalService.classify(pkg) else {
            return XCTFail("Expected nodeGlobal")
        }
        XCTAssertEqual(plan.packageName, "@anthropic-ai/claude-code")
        XCTAssertEqual(plan.toolCandidates.first?.path, "/Users/me/.nvm/versions/node/v20.0.0/bin/npm")
    }

    func testClassifyDetectsBunGlobal() {
        let pkg = URL(
            fileURLWithPath: "/Users/me/.bun/install/global/node_modules/opencode-ai",
            isDirectory: true
        )
        guard case let .nodeGlobal(plan) = CLIRemovalService.classify(pkg) else {
            return XCTFail("Expected nodeGlobal")
        }
        XCTAssertEqual(plan.arguments, ["remove", "-g", "opencode-ai"])
        XCTAssertEqual(plan.toolCandidates.first?.path, "/Users/me/.bun/bin/bun")
        XCTAssertEqual(plan.binDirectory.path, "/Users/me/.bun/bin")
    }

    // MARK: - Node global removal

    func testNpmGlobalIsUninstalledWithMatchingNpmAndBinSwept() async {
        let pkg = URL(fileURLWithPath: "/opt/homebrew/lib/node_modules/firebase-tools", isDirectory: true)
        let npm = URL(fileURLWithPath: "/opt/homebrew/bin/npm")
        let binDir = URL(fileURLWithPath: "/opt/homebrew/bin")
        let dangling = binDir.appendingPathComponent("firebase")

        let recorder = Recorder()
        recorder.executableTools = [npm]
        recorder.symlinksByDirectory = [binDir: [dangling]]
        recorder.danglingSymlinks = [dangling]
        let service = makeService(recorder: recorder)

        let result = await service.remove([pkg])

        XCTAssertEqual(recorder.commandTools, [npm])
        XCTAssertEqual(recorder.commands, [["uninstall", "-g", "firebase-tools"]])
        XCTAssertTrue(recorder.trashed.isEmpty)
        XCTAssertEqual(recorder.removedSymlinks, [dangling])
        XCTAssertEqual(result.deletedURLs, [pkg])
    }

    func testNodeGlobalFallsBackToTrashWhenNoManagerFound() async {
        let pkg = URL(fileURLWithPath: "/opt/homebrew/lib/node_modules/firebase-tools", isDirectory: true)
        let recorder = Recorder() // executableTools empty → npm not found
        let service = makeService(recorder: recorder)

        let result = await service.remove([pkg])

        XCTAssertTrue(recorder.commands.isEmpty)
        XCTAssertEqual(recorder.trashed, [pkg])
        XCTAssertEqual(result.deletedURLs, [pkg])
    }

    func testFailedNodeUninstallIsReported() async {
        let pkg = URL(fileURLWithPath: "/opt/homebrew/lib/node_modules/firebase-tools", isDirectory: true)
        let npm = URL(fileURLWithPath: "/opt/homebrew/bin/npm")
        let recorder = Recorder()
        recorder.executableTools = [npm]
        let service = makeService(
            recorder: recorder,
            commandResult: { _, _ in .init(exitCode: 1, output: "npm error code E404\n") }
        )

        let result = await service.remove([pkg])

        XCTAssertTrue(result.deletedURLs.isEmpty)
        XCTAssertTrue(recorder.trashed.isEmpty)
        XCTAssertEqual(result.failedCount, 1)
        guard case CLIRemovalError.nodeUninstallFailed? = result.failedURLs.first?.1 else {
            return XCTFail("Expected nodeUninstallFailed")
        }
    }

    // MARK: - Helpers

    private func makeService(
        recorder: Recorder,
        brew: URL? = URL(fileURLWithPath: "/opt/homebrew/bin/brew"),
        sizePerItem: Int64 = 100,
        commandResult: @escaping @Sendable (URL, [String]) -> CLIRemovalService.CommandOutput = { _, _ in
            .init(exitCode: 0, output: "")
        }
    ) -> CLIRemovalService {
        CLIRemovalService(
            locateBrew: { brew },
            runCommand: { tool, arguments in
                recorder.recordCommand(tool: tool, arguments: arguments)
                return commandResult(tool, arguments)
            },
            measure: { _ in sizePerItem },
            trashItem: { url in try recorder.recordTrash(url) },
            homebrewLinkDirectories: { recorder.linkDirectories },
            symlinks: { recorder.symlinksByDirectory[$0] ?? [] },
            isDangling: { recorder.danglingSymlinks.contains($0) },
            removeSymlink: { recorder.recordRemovedSymlink($0) },
            isExecutable: { recorder.executableTools.contains($0) },
            userBinDirectories: { recorder.userBinDirectories }
        )
    }
}

/// Thread-safe capture of the service's injected side effects.
private final class Recorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _commands: [[String]] = []
    private var _commandTools: [URL] = []
    private var _trashed: [URL] = []
    private var _removedSymlinks: [URL] = []

    var trashError: Error?
    var linkDirectories: [URL] = []
    var symlinksByDirectory: [URL: [URL]] = [:]
    var danglingSymlinks: Set<URL> = []
    var executableTools: Set<URL> = []
    var userBinDirectories: [URL] = []

    var commands: [[String]] { lock.withLock { _commands } }
    var commandTools: [URL] { lock.withLock { _commandTools } }
    var trashed: [URL] { lock.withLock { _trashed } }
    var removedSymlinks: [URL] { lock.withLock { _removedSymlinks } }

    func recordCommand(tool: URL, arguments: [String]) {
        lock.withLock {
            _commandTools.append(tool)
            _commands.append(arguments)
        }
    }

    func recordTrash(_ url: URL) throws {
        if let trashError { throw trashError }
        lock.withLock { _trashed.append(url) }
    }

    func recordRemovedSymlink(_ url: URL) {
        lock.withLock { _removedSymlinks.append(url) }
    }
}
