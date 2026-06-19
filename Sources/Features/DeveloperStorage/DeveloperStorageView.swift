import SwiftUI

struct DeveloperStorageView: View {
    let findings: [StorageFinding]
    let onDelete: ([URL]) -> Void

    private let developerKinds: [StorageFindingKind] = [
        .xcodeArtifacts,
        .dockerArtifacts,
        .flutterArtifacts,
        .androidStudioArtifacts,
        .androidPackages,
        .pythonDependencies,
        .rustDependencies,
        .goDependencies,
        .phpDependencies,
        .rubyDependencies,
        .dotnetDependencies,
        .gradleDependencies,
        .cliApps,
        .nodeDependencies,
        .aiModelCaches
    ]

    private var developerFindings: [StorageFinding] {
        findings.filter { developerKinds.contains($0.kind) }
    }

    private var totalSize: Int64 {
        developerFindings.reduce(0) { $0 + $1.bytes }
    }

    var body: some View {
        Group {
            if developerFindings.isEmpty {
                AnimatedEmptyState(
                    title: "Developer Storage",
                    message: "Run a scan to discover developer storage artifacts.",
                    systemImage: "chevron.left.forwardslash.chevron.right"
                )
            } else {
                developerList
            }
        }
        .navigationTitle("Developer Storage")
        .navigationSubtitle("\(developerFindings.count) categories, \(StorageFormatting.bytes(totalSize))")
    }

    private var developerList: some View {
        List {
            Section {
                ForEach(developerFindings) { finding in
                    NavigationLink {
                        CategoryDetailView(finding: finding, onDelete: onDelete)
                    } label: {
                        DeveloperStorageRow(finding: finding)
                    }
                }
            } header: {
                HStack {
                    Text("All developer artifacts")
                    Spacer()
                    Text(StorageFormatting.bytes(totalSize))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }
}

struct DeveloperStorageRow: View {
    let finding: StorageFinding

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.color(for: finding.domain).opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: finding.domain.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.color(for: finding.domain))
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(finding.kind.title)
                    .font(.headline)
                Text(finding.kind.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(StorageFormatting.bytes(finding.bytes))
                    .font(.callout.monospacedDigit().weight(.medium))
                Text("\(finding.itemCount) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
