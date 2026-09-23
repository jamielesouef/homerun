import SwiftUI

struct RepositoryDropTargetView: View {
    // MARK: - Constants

    private enum Constants {
        static let cornerRadius: CGFloat = 12
        static let borderWidth: CGFloat = 2
        static let dashLength: CGFloat = 6
        static let symbolSize: CGFloat = 44
        static let backgroundOpacity: CGFloat = 0.12
    }

    // MARK: - View

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .fill(.tint.opacity(Constants.backgroundOpacity))

            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .strokeBorder(
                    .tint,
                    style: StrokeStyle(lineWidth: Constants.borderWidth, dash: [Constants.dashLength])
                )

            VStack(spacing: AppSpacing.small) {
                Image(systemName: "viewfinder")
                    .font(.system(size: Constants.symbolSize))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                Text(String(localized: "Drop to track this repository"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(AppSpacing.regular)
        }
        .padding(AppSpacing.small)
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel(String(localized: "Drop to track this repository"))
    }
}

#if DEBUG
#Preview("Over the list column") {
    RepositoryDropTargetView()
        .frame(width: 320, height: 480)
}

#Preview("Narrow and short") {
    RepositoryDropTargetView()
        .frame(width: 240, height: 180)
}
#endif
