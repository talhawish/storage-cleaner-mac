import SwiftUI

/// One domain's detection rows under a labeled header showing the group's total. Carries the scroll
/// anchor that the breakdown tiles target via `.id(usage.domain)` in the parent list.
struct DetectionGroupSection: View {
    let usage: StorageOverview.DomainUsage
    let onSelectFinding: (StorageFinding) -> Void

    private var tint: Color { AppTheme.color(for: usage.domain) }

    private var subtitle: String {
        let count = usage.findings.count
        return "\(count) detection \(count == 1 ? "type" : "types")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(
                title: usage.domain.title,
                subtitle: subtitle,
                systemImage: usage.domain.symbolName,
                tint: tint
            ) {
                Text(StorageFormatting.bytes(usage.bytes))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(usage.findings.enumerated()), id: \.element.id) { index, finding in
                    if index > 0 {
                        Divider().padding(.leading, 64)
                    }
                    DetectionRow(finding: finding) { onSelectFinding(finding) }
                }
            }
            .cardSurface()
        }
    }
}
