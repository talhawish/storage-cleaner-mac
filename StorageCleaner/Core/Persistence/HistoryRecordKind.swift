import Foundation

/// Identifies why a history record exists so scan inventory and cleanup audit
/// events can be presented independently.
enum HistoryRecordKind: String, Sendable {
    case overallScan
    case cleanupOnly
}
