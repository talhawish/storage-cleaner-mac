import Foundation

struct DemoStorageScanner: StorageScanning {
    private let stepDelay: Duration

    init(stepDelay: Duration = .milliseconds(260)) {
        self.stepDelay = stepDelay
    }

    func scanEvents() -> AsyncStream<ScanEvent> {
        AsyncStream { continuation in
            let task = Task {
                await emitProgress(to: continuation)
                emitResults(to: continuation)
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private var demoLocations: [String] {
        [
            "~/Library/Developer/Xcode",
            "~/Library/Developer/CoreSimulator",
            "~/Developer",
            "~/.npm",
            "~/.gradle",
            "~/Downloads",
            "~/Movies",
            "~/Pictures",
            "~/Desktop",
            "~/Library/Caches/com.apple.Safari",
            "~/Library/Application Support/Google/Chrome",
            "~/.Trash",
            "~/Library/Containers",
            "~/.cache",
            "/opt/homebrew/Cellar",
            "~/.rustup",
            "~/.nvm",
            "~/.volta"
        ]
    }

    private func emitProgress(to continuation: AsyncStream<ScanEvent>.Continuation) async {
        for (index, location) in demoLocations.enumerated() {
            guard !Task.isCancelled else {
                continuation.finish()
                return
            }

            if stepDelay > .zero {
                try? await Task.sleep(for: stepDelay)
            }

            let completedSteps = index + 1
            continuation.yield(
                .progress(
                    fraction: Double(completedSteps) / Double(demoLocations.count),
                    currentLocation: location,
                    scannedItemCount: completedSteps * 12_480,
                    scannerProgress: demoProgress(completedSteps: completedSteps)
                )
            )
        }
    }

    private func demoProgress(completedSteps: Int) -> [ScannerProgress] {
        DemoScanFixture.findings.enumerated().map { index, finding in
            let state: ScannerProgressState
            if index < completedSteps {
                state = .completed
            } else if index == completedSteps {
                state = .scanning
            } else {
                state = .pending
            }

            return ScannerProgress(
                kind: finding.kind,
                title: finding.kind.title,
                state: state,
                inspectedItemCount: state == .completed ? finding.itemCount : 0,
                message: message(for: state)
            )
        }
    }

    private func message(for state: ScannerProgressState) -> String {
        switch state {
        case .pending: "Waiting"
        case .scanning: "Scanning…"
        case .completed: "Completed"
        case .skipped: "Skipped"
        }
    }

    private func emitResults(to continuation: AsyncStream<ScanEvent>.Continuation) {
        guard !Task.isCancelled else {
            continuation.finish()
            return
        }

        let findings = DemoScanFixture.findings
        continuation.yield(
            .completed(
                ScanSnapshot(
                    findings: findings,
                    scannedItemCount: findings.reduce(0) { $0 + $1.itemCount },
                    duration: .seconds(2)
                )
            )
        )
    }
}
