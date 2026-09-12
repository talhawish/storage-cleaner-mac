import Foundation

enum ProjectCountFormatting {
    static func projects(_ count: Int) -> String {
        "\(count.formatted()) \(count == 1 ? "project" : "projects")"
    }

    static func nestedProjects(_ count: Int) -> String {
        "\(count.formatted()) nested \(count == 1 ? "project" : "projects")"
    }
}
