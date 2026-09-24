import SwiftUI

struct LaunchView: View {
    // MARK: - Constants

    private enum Constants {
        static let logoSize: CGFloat = 72
        static let checklistWidth: CGFloat = 380
    }

    // MARK: - Inputs

    let steps: [StartupStep]

    // MARK: - View

    var body: some View {
        VStack(spacing: AppSpacing.large) {
            VStack(spacing: AppSpacing.regular) {
                Image(systemName: "figure.baseball")
                    .font(.system(size: Constants.logoSize))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                Text(String(localized: "homerun"))
                    .font(.largeTitle.weight(.semibold))

                Text(String(localized: "Checking the tools homerun uses on this Mac"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            StartupChecklist(steps: steps)
                .frame(width: Constants.checklistWidth, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.xlarge)
    }
}

#if DEBUG
    #Preview("Just launched") {
        LaunchView(steps: StartupProgressUseCase.waitingSteps())
            .frame(width: 900, height: 600)
    }

    #Preview("Confirming sign-in") {
        LaunchView(
            steps: [
                StartupProgressUseCase.gitChecked(isAvailable: true),
                StartupProgressUseCase.gitHubCLIChecked(isAvailable: true),
                StartupProgressUseCase.running(.gitHubAccounts)
            ]
        )
        .frame(width: 900, height: 600)
    }

    #Preview("git missing") {
        LaunchView(
            steps: [
                StartupProgressUseCase.gitChecked(isAvailable: false),
                StartupProgressUseCase.gitHubCLIChecked(isAvailable: true),
                StartupProgressUseCase.gitHubAccountsChecked(isGitHubCLIAvailable: true, accounts: [])
            ]
        )
        .frame(width: 900, height: 600)
    }
#endif
