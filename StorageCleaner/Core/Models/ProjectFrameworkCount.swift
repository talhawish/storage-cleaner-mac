import Foundation

struct ProjectFrameworkCount: Identifiable, Hashable, Sendable {
    let framework: ProjectFramework
    let count: Int

    var id: ProjectFramework { framework }
}
