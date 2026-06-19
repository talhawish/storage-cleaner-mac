import Foundation

protocol StorageCategoryScanning: Sendable {
    var kind: StorageFindingKind { get }
    var title: String { get }

    func scan() async -> CategoryScanResult
}

struct CategoryScanResult: Equatable, Sendable {
    let finding: StorageFinding?
    let inspectedItemCount: Int
    let message: String
}
