import SwiftUI

struct SyncReviewSheet: View {
    // MARK: - Constants

    private enum Constants {
        static let width: CGFloat = 620
        static let height: CGFloat = 520
    }

    // MARK: - Environment

    @Environment(\.syncService) private var sync
    @Environment(\.settingsService) private var settings

    // MARK: - View

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.regular) {
            header
            Divider()
            steps
            Divider()
            footer
        }
        .padding(AppSpacing.large)
        .frame(width: Constants.width, height: Constants.height)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
            Text(String(localized: "Review the sync"))
                .font(.title2.weight(.semibold))

            Text(String(localized: "Nothing is committed or pushed until you confirm."))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Steps

    @ViewBuilder
    private var steps: some View {
        if let plan = sync.reviewPlan {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.regular) {
                    ForEach(plan.steps) { step in
                        SyncPlanStepView(step: step) { path in
                            sync.toggleUntracked(path, for: step.identifier)
                        } isSelected: { path in
                            sync.isUntrackedSelected(path, for: step.identifier)
                        }
                    }
                }
            }
        } else {
            Spacer()
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Toggle(String(localized: "Ask me every time"), isOn: confirmationBinding)
                .toggleStyle(.checkbox)

            Spacer()

            Button(String(localized: "Cancel")) {
                sync.cancelReview()
            }
            .keyboardShortcut(.cancelAction)

            Button(String(localized: "Sync")) {
                Task {
                    await sync.run()
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(sync.reviewPlan?.isEmpty != false)
        }
    }

    // MARK: - Helpers

    private var confirmationBinding: Binding<Bool> {
        Binding(
            get: { settings.preferences.requiresSyncConfirmation },
            set: { isOn in
                settings.updatePreferences { $0.requiresSyncConfirmation = isOn }
            }
        )
    }
}

#if DEBUG
    #Preview("Review") {
        SyncReviewSheet()
            .environment(\.syncService, PreviewGraph.populated.sync)
            .environment(\.settingsService, PreviewGraph.populated.settings)
    }

    #Preview("Nothing to do") {
        SyncReviewSheet()
            .environment(\.syncService, PreviewGraph.empty.sync)
            .environment(\.settingsService, PreviewGraph.empty.settings)
    }
#endif
