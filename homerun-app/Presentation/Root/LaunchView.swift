import SwiftUI

struct LaunchView: View {
    // MARK: - Constants

    private enum Constants {
        static let logoSize: CGFloat = 72
    }

    // MARK: - View

    var body: some View {
        VStack(spacing: AppSpacing.regular) {
            Image(systemName: "figure.baseball")
                .font(.system(size: Constants.logoSize))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text(String(localized: "homerun"))
                .font(.largeTitle.weight(.semibold))

            ProgressView()
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.xlarge)
    }
}

#if DEBUG
    #Preview("Launch") {
        LaunchView()
            .frame(width: 420, height: 320)
    }
#endif
