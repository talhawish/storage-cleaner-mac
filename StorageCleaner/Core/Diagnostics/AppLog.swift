import OSLog

/// Central factory for the app's `os.Logger` instances so every subsystem
/// logs under the same identifier and categories stay discoverable in
/// Console.app. Add a static accessor per category rather than constructing
/// loggers ad hoc at call sites.
enum AppLog {
    private static let subsystem = "com.horizam.StorageCleaner"

    /// SwiftData scan-history and cleanup-audit persistence.
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
}
