import SwiftUI

struct SnakeProgressView: View {
    // MARK: - Constants

    private enum Constants {
        static let defaultSize: CGFloat = 13
        static let lineWidth: CGFloat = 2
        static let shortestBody: CGFloat = 0.06
        static let chaseDuration: Double = 1.1
        static let turnDuration: Double = 2.4
        static let fullTurn: Double = 360
    }

    // MARK: - State

    @State private var head: CGFloat = Constants.shortestBody
    @State private var tail: CGFloat = 0
    @State private var turn: Double = 0

    // MARK: - Inputs

    var size: CGFloat = Constants.defaultSize

    // MARK: - View

    var body: some View {
        Circle()
            .trim(from: tail, to: head)
            .stroke(.tint, style: StrokeStyle(lineWidth: Constants.lineWidth, lineCap: .round))
            .rotationEffect(.degrees(turn))
            .frame(width: size, height: size)
            .onAppear(perform: startChasing)
            .accessibilityHidden(true)
    }

    // MARK: - Helpers

    private func startChasing() {
        withAnimation(.easeOut(duration: Constants.chaseDuration).repeatForever(autoreverses: false)) {
            head = 1
        }

        withAnimation(.easeIn(duration: Constants.chaseDuration).repeatForever(autoreverses: false)) {
            tail = 1 - Constants.shortestBody
        }

        withAnimation(.linear(duration: Constants.turnDuration).repeatForever(autoreverses: false)) {
            turn = Constants.fullTurn
        }
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

#Preview("Larger, so the chase is visible") {
    SnakeProgressView(size: 96)
        .padding(AppSpacing.xlarge)
}
#endif
