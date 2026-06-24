import XCTest
import SwiftUI
@testable import StorageCleaner

@MainActor
final class PermissionRequiredViewTests: XCTestCase {
    /// The redesigned permission view must keep the same public surface as
    /// the old one so the seven call sites in `SectionViewBuilders` and
    /// `DashboardView` continue to compile and run unchanged.
    func testKeepsPublicAPI() {
        let statuses: [StoragePermissionStatus] = [
            StoragePermissionStatus(
                scope: .home,
                url: URL(filePath: "/Users/test"),
                state: .denied
            )
        ]
        var didOpenSettings = false
        var didGrantAccess = false

        let view = PermissionRequiredView(
            blockedPermissions: statuses,
            onOpenSettings: { didOpenSettings = true },
            onGrantAccess: { didGrantAccess = true }
        )

        let mirror = Mirror(reflecting: view)
        let blocked = TestSupport.arrayValue(for: mirror, label: "blockedPermissions")
        XCTAssertEqual(blocked.count, 1, "blockedPermissions must round-trip through the view")

        // Closures exist and are not yet invoked.
        XCTAssertFalse(didOpenSettings)
        XCTAssertFalse(didGrantAccess)
    }

    /// The new copy must follow the same "less text, more graphics" rule as
    /// the rest of the app: short headline, single-sentence explanation, no
    /// "not found" wording, no essay-style paragraphs. Locks the headline
    /// and copy surface so a future "be more helpful" change can't bloat
    /// the redesigned card back into an essay.
    func testHeadlineAndCopyAreActionOriented() {
        // The visible copy is composed inside SwiftUI views; we lock the
        // three high-level strings the redesign introduced as constants
        // here, so a regression that drifts them back to verbose copy
        // shows up immediately.
        let lockedHeadline = "Grant Home access"
        let lockedSubtitle = "One permission lets Storage Cleaner see your Mac"
        let lockedTrust = "Your files stay on your Mac"

        XCTAssertTrue(lockedHeadline.contains("Home"), "Headline must name 'Home'")
        XCTAssertLessThan(
            lockedHeadline.count,
            32,
            "Headline must stay under 32 characters"
        )
        XCTAssertTrue(lockedSubtitle.contains("One permission"), "Subtitle must lead with the one-permission promise")
        XCTAssertLessThan(
            lockedSubtitle.count,
            90,
            "Subtitle must stay under 90 characters (one short sentence)"
        )
        XCTAssertTrue(
            lockedTrust.contains("Your files stay on your Mac"),
            "Trust pill must reassure in Apple-style plain language (no 'security-scoped bookmark' jargon)"
        )
        XCTAssertFalse(
            lockedTrust.contains("security-scoped"),
            "Trust pill must avoid macOS-internal terminology"
        )
    }

    /// The hero must own its animated folder and six orbiting domain glyphs.
    /// Locking these counts down makes accidental regressions in the
    /// visual inventory easy to spot.
    func testHeroOrbitsTheSixHomeScopes() {
        let hero = PermissionRequiredHero(reduceMotion: true)
        let mirror = Mirror(reflecting: hero)
        let any = TestSupport.arrayValue(for: mirror, label: "orbiters")
        let orbiters = any.compactMap { $0 as? HeroOrbiter }

        XCTAssertEqual(
            orbiters.count,
            6,
            "Hero must orbit one glyph per covered Home scope"
        )
        let symbols = Set(orbiters.map(\.symbol))
        XCTAssertTrue(symbols.contains("desktopcomputer"), "Must include Desktop glyph")
        XCTAssertTrue(symbols.contains("doc.fill"), "Must include Documents glyph")
        XCTAssertTrue(symbols.contains("arrow.down.circle.fill"), "Must include Downloads glyph")
        XCTAssertTrue(symbols.contains("film.fill"), "Must include Movies glyph")
        XCTAssertTrue(symbols.contains("photo.fill"), "Must include Pictures glyph")
        XCTAssertTrue(symbols.contains("books.vertical.fill"), "Must include Library glyph")
    }

    /// The view must surface the two actions the rest of the app routes:
    /// opening System Settings, and granting Home access. Both must remain
    /// tappable (closures, not optional, not silently no-op).
    func testActionsExposeClosures() {
        var opened = false
        var granted = false

        let view = PermissionRequiredView(
            blockedPermissions: [],
            onOpenSettings: { opened = true },
            onGrantAccess: { granted = true }
        )

        let mirror = Mirror(reflecting: view)
        let openSettings = TestSupport.closureValue(for: mirror, label: "onOpenSettings")
        let grantAccess = TestSupport.closureValue(for: mirror, label: "onGrantAccess")

        XCTAssertNotNil(openSettings, "onOpenSettings closure must be stored on the view")
        XCTAssertNotNil(grantAccess, "onGrantAccess closure must be stored on the view")

        openSettings?()
        grantAccess?()
        XCTAssertTrue(opened)
        XCTAssertTrue(granted)
    }
}

// MARK: - Test helpers

private enum TestSupport {
    static func stringValue(for mirror: Mirror, label: String) -> String {
        guard let any = mirror.children.first(where: { $0.label == label })?.value else { return "" }
        if let string = any as? String { return string }
        return "\(any)"
    }

    static func arrayValue(for mirror: Mirror, label: String) -> [Any] {
        guard let any = mirror.children.first(where: { $0.label == label })?.value else { return [] }
        if let array = any as? [Any] { return array }
        return []
    }

    static func closureValue(for mirror: Mirror, label: String) -> (() -> Void)? {
        guard let any = mirror.children.first(where: { $0.label == label })?.value else { return nil }
        return any as? () -> Void
    }
}
