import SwiftUI

struct SnakeProgressView: View {
    // MARK: - Constants

    private enum Constants {
        static let defaultSize: CGFloat = 13
        static let lineWidth: CGFloat = 2
        static let bodyLength: CGFloat = 0.72
        static let rotationDuration: Double = 0.85
        static let fullTurn: Double = 360
    }

    // MARK: - State

    @State private var isChasing = false

    // MARK: - Inputs

    var size: CGFloat = Constants.defaultSize

    // MARK: - View

    var body: some View {
        Circle()
            .trim(from: 0, to: Constants.bodyLength)
            .stroke(
                AngularGradient(
                    colors: [.accentColor.opacity(0), .accentColor],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: Constants.lineWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(isChasing ? Constants.fullTurn : 0))
            .frame(width: size, height: size)
            .animation(
                .linear(duration: Constants.rotationDuration).repeatForever(autoreverses: false),
                value: isChasing
            )
            .onAppear {
                isChasing = true
            }
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Beside text, as the badge uses it") {
    HStack(spacing: AppSpacing.xsmall) {
        SnakeProgressView()

        Text(verbatim: "Reading")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .padding(AppSpacing.regular)
}

#Preview("Larger") {
    SnakeProgressView(size: 48)
        .padding(AppSpacing.xlarge)
}
#endif
