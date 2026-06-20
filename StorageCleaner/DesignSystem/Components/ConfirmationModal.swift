import SwiftUI

/// The opinionated confirmation primitive used by every "are you sure?"
/// sheet in the app. Built on top of `AppModal` so confirmations inherit the
/// same header / scrollable body / action-bar structure as detail sheets.
///
/// Configure the look with a `variant` (drives the icon and accent color)
/// and a `message` or rich `content` body. Destructive variants hide the
/// close X so the user must explicitly choose Cancel or Confirm.
struct ConfirmationModal<Content: View>: View {
    /// Visual category. Each variant picks a default SF Symbol and accent
    /// color from `AppTheme`; callers can override either explicitly.
    enum Variant: Sendable {
        case info
        case warning
        case error
        case success
        case destructive
        case neutral

        var defaultIconName: String {
            switch self {
            case .info: "info.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .error: "xmark.octagon.fill"
            case .success: "checkmark.circle.fill"
            case .destructive: "trash.fill"
            case .neutral: "questionmark.circle.fill"
            }
        }

        var defaultColor: Color {
            switch self {
            case .info: AppTheme.accent
            case .warning: AppTheme.orange
            case .error: AppTheme.rose
            case .success: AppTheme.mint
            case .destructive: AppTheme.rose
            case .neutral: .secondary
            }
        }
    }

    let variant: Variant
    let title: String
    let subtitle: String?
    let message: String?
    let iconSystemName: String?
    let iconTint: Color?
    let trailing: AppModalTrailing?
    let showsCloseButton: Bool
    let confirm: AppModalActionBar.Action
    let cancel: AppModalActionBar.CancelAction?
    let isProcessing: Bool
    @ViewBuilder let content: () -> Content

    /// Full initializer. Pass `content: { ... }` even when there's no body —
    /// use `{ EmptyView() }` for simple title+message confirmations.
    init(
        variant: Variant = .info,
        title: String,
        subtitle: String? = nil,
        message: String? = nil,
        iconSystemName: String? = nil,
        iconTint: Color? = nil,
        trailing: AppModalTrailing? = nil,
        showsCloseButton: Bool = true,
        confirm: AppModalActionBar.Action,
        cancel: AppModalActionBar.CancelAction? = nil,
        isProcessing: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.variant = variant
        self.title = title
        self.subtitle = subtitle
        self.message = message
        self.iconSystemName = iconSystemName
        self.iconTint = iconTint
        self.trailing = trailing
        self.showsCloseButton = showsCloseButton
        self.confirm = confirm
        self.cancel = cancel
        self.isProcessing = isProcessing
        self.content = content
    }

    /// Convenience initializer for the common case: no additional rich
    /// content. The body shows only the optional `message` (rendered as a
    /// banner). Use the full initializer when you need to drop in a file
    /// list, an info card, or any other custom view.
    init(
        variant: Variant = .info,
        title: String,
        subtitle: String? = nil,
        message: String? = nil,
        iconSystemName: String? = nil,
        iconTint: Color? = nil,
        trailing: AppModalTrailing? = nil,
        showsCloseButton: Bool = true,
        confirm: AppModalActionBar.Action,
        cancel: AppModalActionBar.CancelAction? = nil,
        isProcessing: Bool = false
    ) where Content == EmptyView {
        self.init(
            variant: variant,
            title: title,
            subtitle: subtitle,
            message: message,
            iconSystemName: iconSystemName,
            iconTint: iconTint,
            trailing: trailing,
            showsCloseButton: showsCloseButton,
            confirm: confirm,
            cancel: cancel,
            isProcessing: isProcessing
        ) {
            EmptyView()
        }
    }

    private var resolvedIcon: String { iconSystemName ?? variant.defaultIconName }
    private var resolvedTint: Color { iconTint ?? variant.defaultColor }

    var body: some View {
        AppModal(
            idealWidth: idealWidth,
            minHeight: idealHeight,
            idealHeight: idealHeight,
            maxHeight: maxHeight
        ) {
            VStack(spacing: 0) {
                AppModalHeader(
                    iconSystemName: resolvedIcon,
                    iconTint: resolvedTint,
                    title: title,
                    subtitle: subtitle,
                    trailing: trailing,
                    showsCloseButton: showsCloseButton
                )

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                        if let message {
                            AppModalBanner(
                                systemImage: variant.defaultIconName,
                                tint: resolvedTint,
                                text: message
                            )
                        }
                        content()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppTheme.Spacing.extraLarge)
                }

                Divider()
                AppModalActionBar(
                    cancel: cancel,
                    actions: [confirm],
                    isProcessing: isProcessing,
                    style: .compact
                )
            }
        }
    }

    // MARK: - Sizing

    private var idealWidth: CGFloat {
        switch variant {
        case .destructive, .warning: 560
        default: 480
        }
    }

    private var idealHeight: CGFloat { 400 }
    private var maxHeight: CGFloat { 640 }
}
