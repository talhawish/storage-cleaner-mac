import SwiftUI

/// The visual shell every modal in the app is rendered into.
///
/// `AppModal` is intentionally presentation-only: it provides a window-sized
/// container, a hairline border, and a soft shadow so the contents look the
/// same whether they're a deletion confirmation, a project detail card, or a
/// preview sheet. Callers compose the header, body, and footer themselves
/// from the sibling subviews (`AppModalHeader`, `AppModalSection`,
/// `AppModalActionBar`) so each modal still owns its layout.
///
/// The default width is generous (`idealWidth = 680`) and the height is
/// bounded so the modal never grows past the window. Both can be overridden
/// per call site.
struct AppModal<Content: View>: View {
    var idealWidth: CGFloat = 680
    var minHeight: CGFloat = 460
    var idealHeight: CGFloat = 540
    var maxHeight: CGFloat = 760
    var background: Color = AppTheme.appBackground
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .frame(
            minWidth: idealWidth * 0.85,
            idealWidth: idealWidth,
            maxWidth: idealWidth * 1.15,
            minHeight: minHeight,
            idealHeight: idealHeight,
            maxHeight: maxHeight
        )
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 32, x: 0, y: 16)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Header

/// The top bar of an `AppModal`. Composes an icon tile, a two-line title
/// block, an optional trailing element (size badge, status, etc.), and an
/// optional close button. Sized so the header always reads as the same
/// height across the app.
struct AppModalHeader: View {
    let iconSystemName: String?
    let iconTint: Color
    let title: String
    let subtitle: String?
    let trailing: AppModalTrailing?
    let showsCloseButton: Bool
    let accessibilityIdentifier: String?

    @State private var isCloseHovering = false
    @Environment(\.dismiss)
    private var dismiss

    init(
        iconSystemName: String? = nil,
        iconTint: Color = AppTheme.accent,
        title: String,
        subtitle: String? = nil,
        trailing: AppModalTrailing? = nil,
        showsCloseButton: Bool = true,
        accessibilityIdentifier: String? = nil
    ) {
        self.iconSystemName = iconSystemName
        self.iconTint = iconTint
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.showsCloseButton = showsCloseButton
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            if let iconSystemName {
                iconTile(systemName: iconSystemName, tint: iconTint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 12)

            if let trailing {
                trailing.view
            }

            if showsCloseButton {
                closeButton
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier ?? "app-modal-header")
    }

    private func iconTile(systemName: String, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.14))
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: 40, height: 40)
        .accessibilityHidden(true)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isCloseHovering ? .primary : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(
                            isCloseHovering
                                ? Color.secondary.opacity(0.28)
                                : Color.secondary.opacity(0.14)
                        )
                )
                .overlay(
                    Circle()
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isCloseHovering = $0 }
        .accessibilityLabel("Close")
        .help("Close")
    }
}

/// Trailing content for an `AppModalHeader`. Three flavours cover the existing
/// sheets: a byte-size badge (delete confirmations), a status pill (info
/// sheets), or a fully custom view (anything else).
enum AppModalTrailing: View {
    case sizeBadge(value: String, tint: Color)
    case statusBadge(text: String, tint: Color)
    case custom(AnyView)

    var body: some View { view }

    @ViewBuilder var view: some View {
        switch self {
        case let .sizeBadge(value, tint):
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(tint)
            }
        case let .statusBadge(text, tint):
            Text(text)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(tint.opacity(0.14), in: Capsule())
                .foregroundStyle(tint)
        case let .custom(content):
            content
        }
    }
}

// MARK: - Body

/// A single content section inside an `AppModal`. Renders a small section
/// header (icon + title + subtitle) followed by whatever the caller slots in,
/// so every modal uses the same rhythm for its content blocks.
struct AppModalSection<Content: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String?
    let tint: Color
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        tint: Color = AppTheme.accent,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                tint: tint
            )
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A horizontal stat tile used inside an `AppModal` body. Tiles share the
/// same width via `frame(maxWidth: .infinity)` so a `HStack` of them lines up
/// cleanly.
struct AppModalStat: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.mediumLarge)
        .cardSurface()
    }
}

/// A surface that fills the available width inside an `AppModalSection`. The
/// `cardSurface()` modifier is applied to whatever the caller provides, so
/// sections can be plain (text only) or card-wrapped.
struct AppModalCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppTheme.Spacing.mediumLarge)
            .cardSurface()
    }
}

/// A subtle informational banner used inside a modal. The tint drives the
/// icon, the text, and the background — `.orange` for "review first",
/// `.mint` for "safe to proceed", etc.
struct AppModalBanner: View {
    let systemImage: String
    let tint: Color
    let text: String

    init(systemImage: String, tint: Color, text: String) {
        self.systemImage = systemImage
        self.tint = tint
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(AppTheme.Spacing.mediumLarge)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Action bar

/// The bottom row of a confirmation or detail modal.
///
/// - When `cancel` is non-nil, it renders on the leading edge with a
///   `Cancel`-style label. Most destructive confirmations (Delete, etc.) keep
///   this so the user can back out.
/// - When `cancel` is nil (the default) only the actions render, right-aligned
///   against a leading spacer. Detail sheets pair this with a close-X in the
///   header so a separate "Done" button is redundant.
/// - `style: .compact` shrinks the action buttons to `.controlSize(.regular)`
///   and tightens the padding, so a 3–4 button action bar (e.g. the project
///   detail's Show in Finder / Hibernate / Hibernate & Compress) fits on one
///   line at the modal's default width.
struct AppModalActionBar: View {
    enum Style: Sendable {
        case regular
        case compact
    }

    let cancel: CancelAction?
    let actions: [Action]
    let isProcessing: Bool
    let style: Style

    @Environment(\.dismiss)
    private var dismiss

    init(
        cancel: CancelAction? = nil,
        actions: [Action] = [],
        isProcessing: Bool = false,
        style: Style = .regular
    ) {
        self.cancel = cancel
        self.actions = actions
        self.isProcessing = isProcessing
        self.style = style
    }

    var body: some View {
        HStack(spacing: 12) {
            if let cancel {
                Button {
                    cancel.action()
                    if cancel.dismissAfterAction { dismiss() }
                } label: {
                    Text(cancel.title)
                        .frame(minWidth: 80)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
                .disabled(isProcessing)
                .help(cancel.help ?? "")
            } else {
                Spacer(minLength: 0)
            }

            Spacer(minLength: 8)

            ForEach(actions) { action in
                AppModalActionButton(
                    action: action,
                    isProcessing: isProcessing,
                    style: style
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, style == .compact ? 14 : 18)
    }
}

extension AppModalActionBar {
    struct CancelAction {
        var title: String = "Cancel"
        var help: String?
        /// When `true` (the default), the sheet is dismissed after the
        /// `action` runs. Set to `false` for the rare case where the cancel
        /// button needs to run a hook but keep the sheet open.
        var dismissAfterAction: Bool
        var action: () -> Void

        init(
            title: String = "Cancel",
            help: String? = nil,
            dismissAfterAction: Bool = true,
            action: @escaping () -> Void = {}
        ) {
            self.title = title
            self.help = help
            self.dismissAfterAction = dismissAfterAction
            self.action = action
        }
    }

    struct Action: Identifiable {
        let id: UUID
        var title: String
        var systemImage: String?
        /// Explicit override. Ignored when `isDestructive` is `true` (red wins).
        var tint: Color?
        var isProminent: Bool
        /// Shortcut for destructive actions — sets the tint to red and the
        /// button role to `.destructive`, regardless of `tint`.
        var isDestructive: Bool
        var isDisabled: Bool
        var isDefault: Bool
        var isIconOnly: Bool
        var help: String?
        var action: () -> Void

        init(
            id: UUID = UUID(),
            title: String,
            systemImage: String? = nil,
            tint: Color? = nil,
            isProminent: Bool = false,
            isDestructive: Bool = false,
            isDisabled: Bool = false,
            isDefault: Bool = false,
            isIconOnly: Bool = false,
            help: String? = nil,
            action: @escaping () -> Void = {}
        ) {
            self.id = id
            self.title = title
            self.systemImage = systemImage
            self.tint = tint
            self.isProminent = isProminent
            self.isDestructive = isDestructive
            self.isDisabled = isDisabled
            self.isDefault = isDefault
            self.isIconOnly = isIconOnly
            self.help = help
            self.action = action
        }

        /// Resolved tint: explicit override > destructive red > app accent.
        fileprivate var resolvedTint: Color {
            if let tint { return tint }
            if isDestructive { return .red }
            return AppTheme.accent
        }
    }
}

private struct AppModalActionButton: View {
    let action: AppModalActionBar.Action
    let isProcessing: Bool
    let style: AppModalActionBar.Style

    var body: some View {
        Group {
            if action.isProminent {
                primaryButton
            } else {
                secondaryButton
            }
        }
        .controlSize(style == .compact ? .regular : .large)
        .tint(action.resolvedTint)
        .disabled(action.isDisabled || isProcessing)
        .help(action.help ?? action.title)
    }

    private var role: ButtonRole? {
        action.isDestructive ? .destructive : nil
    }

    @ViewBuilder private var primaryButton: some View {
        if action.isDefault {
            Button(role: role, action: action.action) { label }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        } else {
            Button(role: role, action: action.action) { label }
                .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder private var secondaryButton: some View {
        if action.isDefault {
            Button(role: role, action: action.action) { label }
                .buttonStyle(.bordered)
                .keyboardShortcut(.defaultAction)
        } else {
            Button(role: role, action: action.action) { label }
                .buttonStyle(.bordered)
        }
    }

    private var label: some View {
        HStack(spacing: 6) {
            if let symbol = action.systemImage {
                Image(systemName: symbol)
                    .accessibilityHidden(true)
            }
            if !action.isIconOnly {
                Text(action.title)
            }
        }
        .frame(minWidth: action.isIconOnly || style == .compact ? 0 : 100)
    }
}
