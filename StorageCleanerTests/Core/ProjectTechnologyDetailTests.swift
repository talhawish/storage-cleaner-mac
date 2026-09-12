import Foundation
import XCTest
@testable import StorageCleaner

final class ProjectTechnologyDetailTests: XCTestCase {
    func testLayeredFrameworkCountsDoNotDoubleCountStorage() throws {
        let next = project(
            name: "next",
            frameworks: [.nextJS, .react],
            totalSize: 10_000,
            dependencySize: 6_000
        )
        let react = project(
            name: "react",
            frameworks: [.react],
            totalSize: 8_000,
            dependencySize: 3_000
        )
        let detail = ProjectTechnologyDetail(technology: .nodeJS, projects: [next, react])

        XCTAssertEqual(detail.totalSize, 18_000)
        XCTAssertEqual(detail.dependencySize, 9_000)
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: detail.frameworkBreakdown.map { ($0.framework, $0.count) }),
            [.react: 2, .nextJS: 1]
        )
    }

    func testHibernatableSizeHonorsActivityThreshold() {
        let inactive = project(
            name: "inactive",
            frameworks: [.nuxt, .vue],
            totalSize: 10_000,
            dependencySize: 7_000,
            lastModified: .distantPast
        )
        let active = project(
            name: "active",
            frameworks: [.vue],
            totalSize: 9_000,
            dependencySize: 5_000,
            lastModified: .now
        )
        let detail = ProjectTechnologyDetail(technology: .nodeJS, projects: [inactive, active])

        XCTAssertEqual(detail.inactiveProjects(olderThan: .oneMonth).map(\.name), ["inactive"])
        XCTAssertEqual(detail.hibernatableSize(olderThan: .oneMonth), 7_000)
    }

    private func project(
        name: String,
        frameworks: Set<ProjectFramework>,
        totalSize: Int64,
        dependencySize: Int64,
        lastModified: Date = .distantPast
    ) -> ProjectInfo {
        ProjectInfo(
            name: name,
            path: URL(fileURLWithPath: "/tmp/\(name)", isDirectory: true),
            technology: .nodeJS,
            frameworks: frameworks,
            lastModifiedDate: lastModified,
            totalSize: totalSize,
            childProjectCount: 0,
            dependencySize: dependencySize
        )
    }
}
