import Foundation
import SwiftData

enum PersistenceController {
    static let shared = makeContainer(inMemory: false)

    nonisolated(unsafe) static var preview = makeContainer(inMemory: true)

    /// A fresh in-memory container for transient runs (UI tests, demo mode) that must never
    /// touch the user's on-disk store.
    static func makeInMemory() -> ModelContainer {
        makeContainer(inMemory: true)
    }

    private static var schema: Schema {
        Schema([
            StoredScan.self,
            StoredFinding.self,
            StoredCleanupAction.self
        ])
    }

    /// Falls back to an in-memory store if the on-disk store cannot be opened, so a corrupt or
    /// inaccessible database degrades gracefully instead of crashing the app at launch. History
    /// is non-critical, so losing it is preferable to refusing to start.
    private static func makeContainer(inMemory: Bool) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
            return container
        }

        let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        if let container = try? ModelContainer(for: schema, configurations: [fallback]) {
            return container
        }

        fatalError("Unable to create a SwiftData ModelContainer for StorageCleaner.")
    }
}
