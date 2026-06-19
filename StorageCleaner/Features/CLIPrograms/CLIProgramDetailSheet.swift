import SwiftUI
import AppKit

/// The correct "preview" for a CLI program: a details panel with file-system
/// actions, replacing the media image preview that CLI Programs used to show.
struct CLIProgramDetailSheet: View {
    let program: CLIProgram
    let size: Int64?

    @Environment(\.dismiss)
    private var dismiss
    @State private var exists = true

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    description
                    detailRows
                    safetyNote
                }
                .padding(24)
            }

            Divider()

            footer
        }
        .frame(width: 480, height: 460)
        .task { exists = FileManager.default.fileExists(atPath: program.url.path) }
    }

    private var header: some View {
        HStack(spacing: 16) {
            CLIProgramIconView(program: program, size: 60)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(program.displayName)
                        .font(.title2.weight(.semibold))
                    StatusBadge(safety: program.safety)
                }
                Text(program.category.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(24)
    }

    private var description: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What this is")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            Text(program.subtitle)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var detailRows: some View {
        VStack(spacing: 0) {
            detailRow("Size", value: size.map(StorageFormatting.bytes) ?? "Calculating…")
            Divider()
            detailRow("Location", value: StoragePathFormatting.abbreviatingHome(program.url), monospaced: true)
            Divider()
            detailRow("Status", value: exists ? "Present on disk" : "Missing")
        }
        .padding(.vertical, 4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func detailRow(_ label: String, value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(monospaced ? .subheadline.monospaced() : .subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var safetyNote: some View {
        HStack(spacing: 10) {
            Image(systemName: program.safety == .safe ? "checkmark.shield.fill" : "eye.fill")
                .foregroundStyle(program.safety == .safe ? AppTheme.mint : AppTheme.orange)
                .accessibilityHidden(true)
            Text(safetyMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(14)
        .background(
            (program.safety == .safe ? AppTheme.mint : AppTheme.orange).opacity(0.08),
            in: RoundedRectangle(cornerRadius: 10)
        )
    }

    private var safetyMessage: String {
        switch program.safety {
        case .safe:
            "This is a re-downloadable cache. Removing it is safe — tools will rebuild it on next use."
        case .review:
            "Removing this uninstalls toolchains or versions. Review before deleting; you may need to reinstall."
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([program.url])
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
                    .frame(minWidth: 150)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!exists)

            Spacer()

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
        }
        .padding(24)
    }
}
