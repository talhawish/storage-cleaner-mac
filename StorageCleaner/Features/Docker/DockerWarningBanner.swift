import SwiftUI

struct DockerWarningBanner: View {
    let warnings: [String]

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Some Docker information is unavailable")
                    .font(.callout.weight(.semibold))
                ForEach(warnings, id: \.self) { warning in
                    Text(warning)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(AppTheme.orange.opacity(0.08))
        .accessibilityElement(children: .combine)
    }
}
