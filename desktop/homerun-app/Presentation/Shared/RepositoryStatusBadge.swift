import SwiftUI

struct RepositoryStatusBadge: View {
    // MARK: - Inputs

    let status: RepositoryStatus

    // MARK: - View

    var body: some View {
        Label(status.title, systemImage: status.symbolName)
            .font(.caption)
            .foregroundStyle(tint)
            .labelStyle(.titleAndIcon)
            .accessibilityLabel(status.title)
    }

    // MARK: - Helpers

    private var tint: Color {
        switch status {
        case .clean:
            .green
        case .ahead,
             .dirty:
            .orange
        case .behind:
            .blue
        case .diverged,
             .failed,
             .unreadable:
            .red
        case .notCloned:
            .secondary
        }
    }
}

#if DEBUG
#Preview("Every status") {
    VStack(alignment: .leading, spacing: AppSpacing.small) {
        ForEach(RepositoryStatus.allCases, id: \.rawValue) { status in
            RepositoryStatusBadge(status: status)
        }
    }
    .padding(AppSpacing.regular)
}
#endif
