import SwiftUI

/// Per-section pre-scan (`InitialStateView`) and post-scan (`EmptyStateView`)
/// copy. Kept in its own file to keep `AppShellView` under the 600-line
/// ceiling while letting every section have its own inviting, hand-tuned
/// welcome message and scan highlights.
extension AppShellView {
    func developerStorageInitialState(action: @escaping () -> Void) -> some View {
        InitialStateView(
            title: "Discover your developer storage",
            subtitle: "We'll scan build artifacts, simulators, package caches, "
                + "containers, and SDK leftovers — anything your toolchain can rebuild.",
            highlights: [
                InitialStateHighlight(title: "Build artifacts", systemImage: "hammer.fill"),
                InitialStateHighlight(title: "Simulators", systemImage: "iphone.gen3"),
                InitialStateHighlight(title: "Package caches", systemImage: "shippingbox.fill"),
                InitialStateHighlight(title: "SDKs & Runtimes", systemImage: "square.stack.3d.up.fill")
            ],
            actionTitle: "Scan Developer Storage",
            systemImage: "chevron.left.forwardslash.chevron.right",
            tint: AppTheme.accent,
            action: action
        )
        .accessibilityIdentifier("developer-storage-initial")
    }

    func developerStorageEmptyState(action: @escaping () -> Void) -> some View {
        EmptyStateView(
            title: "Nothing to clean here",
            message: "No re-creatable developer files were found in the selected locations. "
                + "Run another scan if you've built new projects since the last one.",
            systemImage: "checkmark.seal.fill",
            tint: AppTheme.mint,
            actionTitle: "Scan Again",
            action: action
        )
        .accessibilityIdentifier("developer-storage-empty")
    }

    func largeFilesInitialState(action: @escaping () -> Void) -> some View {
        InitialStateView(
            title: "Find the bulky files you forgot about",
            subtitle: "We scan Desktop, Downloads, Documents, Pictures, and Movies for "
                + "review-safe large files that you can safely remove.",
            highlights: [
                InitialStateHighlight(title: "Desktop", systemImage: "desktopcomputer"),
                InitialStateHighlight(title: "Downloads", systemImage: "arrow.down.circle.fill"),
                InitialStateHighlight(title: "Documents", systemImage: "doc.fill"),
                InitialStateHighlight(title: "Media", systemImage: "photo.fill")
            ],
            actionTitle: "Scan Large Files",
            systemImage: "doc.badge.ellipsis",
            tint: AppTheme.cyan,
            action: action
        )
        .accessibilityIdentifier("large-files-initial")
    }

    func largeFilesEmptyState(action: @escaping () -> Void) -> some View {
        EmptyStateView(
            title: "No large files in scope",
            message: "Nothing above the size threshold turned up in the locations you selected. "
                + "Lower the minimum size to see more, or scan again after new files arrive.",
            systemImage: "checkmark.seal.fill",
            tint: AppTheme.mint,
            actionTitle: "Scan Again",
            action: action
        )
        .accessibilityIdentifier("large-files-empty")
    }

    func leftoversInitialState(action: @escaping () -> Void) -> some View {
        InitialStateView(
            title: "Hunt down leftover installers",
            subtitle: "We'll inspect Downloads, Desktop, and Documents for disk images, "
                + "packages, and app bundles that are safe to remove.",
            highlights: [
                InitialStateHighlight(title: "DMG & ISO", systemImage: "opticaldiscdrive"),
                InitialStateHighlight(title: "Packages", systemImage: "shippingbox"),
                InitialStateHighlight(title: "App bundles", systemImage: "app.badge"),
                InitialStateHighlight(title: "APKs", systemImage: "iphone.gen2")
            ],
            actionTitle: "Scan Leftovers",
            systemImage: "archivebox.fill",
            tint: AppTheme.orange,
            action: action
        )
        .accessibilityIdentifier("leftovers-initial")
    }

    func leftoversEmptyState(action: @escaping () -> Void) -> some View {
        EmptyStateView(
            title: "No leftover installers found",
            message: "Downloads, Desktop, and Documents are free of DMG, ISO, PKG, IPA, "
                + "and APK packages. Run another scan to refresh.",
            systemImage: "checkmark.seal.fill",
            tint: AppTheme.mint,
            actionTitle: "Scan Again",
            action: action
        )
        .accessibilityIdentifier("leftovers-empty")
    }

    func systemJunkInitialState(action: @escaping () -> Void) -> some View {
        InitialStateView(
            title: "Find orphaned app data",
            subtitle: "We compare entries in your user Library against installed apps, "
                + "and surface caches, containers, and crash reports that are safe to clean.",
            highlights: [
                InitialStateHighlight(title: "App Support", systemImage: "externaldrive"),
                InitialStateHighlight(title: "Caches", systemImage: "internaldrive"),
                InitialStateHighlight(title: "Containers", systemImage: "shippingbox"),
                InitialStateHighlight(title: "Crash reports", systemImage: "exclamationmark.triangle")
            ],
            actionTitle: "Scan System Junk",
            systemImage: "trash.slash.fill",
            tint: AppTheme.rose,
            action: action
        )
        .accessibilityIdentifier("system-junk-initial")
    }

    func systemJunkEmptyState(action: @escaping () -> Void) -> some View {
        EmptyStateView(
            title: "No orphaned app data",
            message: "Your installed apps line up cleanly with their Library entries, and no "
                + "stale crash reports turned up. Scan again to keep it that way.",
            systemImage: "checkmark.seal.fill",
            tint: AppTheme.mint,
            actionTitle: "Scan Again",
            action: action
        )
        .accessibilityIdentifier("system-junk-empty")
    }

    func mediaCategoryInitialState(title: String, action: @escaping () -> Void) -> some View {
        InitialStateView(
            title: "Review your \(title.lowercased())",
            subtitle: "We'll look through common media locations for screenshots and screen "
                + "recordings that have grown large and are safe to clean up.",
            highlights: [
                InitialStateHighlight(title: "Screenshots", systemImage: "camera.viewfinder"),
                InitialStateHighlight(title: "Recordings", systemImage: "video.fill"),
                InitialStateHighlight(title: "Reviewed safely", systemImage: "checkmark.shield.fill")
            ],
            actionTitle: "Scan \(title)",
            systemImage: "camera.viewfinder",
            tint: AppTheme.pink,
            action: action
        )
        .accessibilityIdentifier("media-category-initial")
    }

    func mediaCategoryEmptyState(
        title: String,
        message: String,
        action: @escaping () -> Void
    ) -> some View {
        EmptyStateView(
            title: "Nothing to clean in \(title)",
            message: message,
            systemImage: "checkmark.seal.fill",
            tint: AppTheme.mint,
            actionTitle: "Scan Again",
            action: action
        )
        .accessibilityIdentifier("media-category-empty")
    }

    func duplicatesInitialState(action: @escaping () -> Void) -> some View {
        InitialStateView(
            title: "Find byte-identical copies",
            subtitle: "We'll compare your media, Documents, Downloads, and Desktop by content "
                + "to surface exact duplicate photos, videos, and documents.",
            highlights: [
                InitialStateHighlight(title: "Photos", systemImage: "photo.fill"),
                InitialStateHighlight(title: "Videos", systemImage: "video.fill"),
                InitialStateHighlight(title: "Documents", systemImage: "doc.fill"),
                InitialStateHighlight(title: "Content-hashed", systemImage: "number")
            ],
            actionTitle: "Scan for Duplicates",
            systemImage: "square.on.square",
            tint: AppTheme.indigo,
            action: action
        )
        .accessibilityIdentifier("duplicates-initial")
    }

    func duplicatesEmptyState(action: @escaping () -> Void) -> some View {
        EmptyStateView(
            title: "No duplicates found",
            message: "Every photo, video, and document in the scanned locations is unique. "
                + "Run another scan after adding new media to keep duplicates in check.",
            systemImage: "checkmark.seal.fill",
            tint: AppTheme.mint,
            actionTitle: "Scan Again",
            action: action
        )
        .accessibilityIdentifier("duplicates-empty")
    }

    func cliProgramsInitialState(message: String, action: @escaping () -> Void) -> some View {
        InitialStateView(
            title: "Inventory your command-line tools",
            subtitle: message,
            highlights: [
                InitialStateHighlight(title: "Homebrew", systemImage: "mug.fill"),
                InitialStateHighlight(title: "Version managers", systemImage: "square.stack.3d.up"),
                InitialStateHighlight(title: "Global packages", systemImage: "shippingbox"),
                InitialStateHighlight(title: "Standalone binaries", systemImage: "terminal")
            ],
            actionTitle: "Scan CLI Tools",
            systemImage: "terminal.fill",
            tint: AppTheme.teal,
            action: action
        )
        .accessibilityIdentifier("cli-programs-initial")
    }

    func cliProgramsEmptyState(message: String, action: @escaping () -> Void) -> some View {
        EmptyStateView(
            title: "No CLI tool leftovers",
            message: message,
            systemImage: "checkmark.seal.fill",
            tint: AppTheme.mint,
            actionTitle: "Scan Again",
            action: action
        )
        .accessibilityIdentifier("cli-programs-empty")
    }
}
