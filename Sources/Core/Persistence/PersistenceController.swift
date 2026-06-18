import Foundation
import SwiftData

enum PersistenceController {
    static let shared: ModelContainer = {
        let schema = Schema([
            StoredScan.self,
            StoredFinding.self,
            StoredCleanupAction.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    nonisolated(unsafe) static var preview: ModelContainer = {
        let schema = Schema([
            StoredScan.self,
            StoredFinding.self,
            StoredCleanupAction.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try! ModelContainer(for: schema, configurations: [config])
    }()
}
