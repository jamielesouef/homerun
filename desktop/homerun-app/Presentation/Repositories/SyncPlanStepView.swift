import SwiftUI

struct SyncPlanStepView: View {
    // MARK: - Inputs

    let step: SyncPlanStep
    let toggleUntracked: (String) -> Void
    let isSelected: (String) -> Bool

    // MARK: - View

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            header
            trackedChanges
            untrackedFiles
            warnings
        }
        .padding(AppSpacing.medium)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: AppSpacing.small))
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
            HStack {
                Text(step.repositoryName)
                    .font(.headline)
                    .lineLimit(2)

                Spacer(minLength: AppSpacing.small)

                if let branch = step.branch {
                    Label(branch, systemImage: "arrow.triangle.branch")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Text(step.action.summary)
                .font(.callout)
                .foregroundStyle(step.isActionable ? Color.primary : Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Changes

    @ViewBuilder
    private var trackedChanges: some View {
        if step.trackedChanges.isEmpty == false {
            VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                Text(String(localized: "Tracked changes, included automatically"))
                    .font(.caption.weight(.semibold))

                ForEach(step.trackedChanges) { change in
                    Label("\(change.status.rawValue): \(change.path)", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }

    @ViewBuilder
    private var untrackedFiles: some View {
        if step.selectableUntrackedPaths.isEmpty == false {
            VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                Text(String(localized: "Untracked files, only if you pick them"))
                    .font(.caption.weight(.semibold))

                ForEach(step.selectableUntrackedPaths, id: \.self) { path in
                    Toggle(isOn: binding(for: path)) {
                        Text(path)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .toggleStyle(.checkbox)
                }
            }
        }
    }

    @ViewBuilder
    private var warnings: some View {
        if step.outstandingBranches.isEmpty == false {
            Label(
                String(localized: "Other branches still unsynced: \(step.outstandingBranches.map(\.name).joined(separator: ", "))"),
                systemImage: "arrow.triangle.branch"
            )
            .font(.caption)
            .foregroundStyle(.orange)
        }

        if step.submoduleChanges.isEmpty == false {
            Label(
                String(localized: "Submodules need attention: \(step.submoduleChanges.map(\.path).joined(separator: ", "))"),
                systemImage: "shippingbox"
            )
            .font(.caption)
            .foregroundStyle(.orange)
        }
    }

    // MARK: - Helpers

    private func binding(for path: String) -> Binding<Bool> {
        Binding(
            get: { isSelected(path) },
            set: { _ in toggleUntracked(path) }
        )
    }
}

#if DEBUG
#Preview("Commit and push") {
    SyncPlanStepView(
        step: SyncPlanStep(
            identifier: "a",
            repositoryName: "app",
            branch: "feature/login",
            action: .commitAndPush(willCommit: true, setsUpstream: false),
            trackedChanges: [
                GitFileChange(path: "Sources/Login.swift", status: .modified),
                GitFileChange(path: "Sources/Removed.swift", status: .deleted)
            ],
            selectableUntrackedPaths: ["Notes.md"],
            includedUntrackedPaths: [],
            outstandingBranches: [GitBranchRef(name: "spike", upstream: nil, aheadCount: 0, behindCount: 0)],
            submoduleChanges: [GitSubmoduleChange(path: "Vendor/Lib", kind: .commitDiffers)]
        ),
        toggleUntracked: { _ in },
        isSelected: { _ in false }
    )
    .padding()
    .frame(width: 560)
}

#Preview("Blocked") {
    SyncPlanStepView(
        step: SyncPlanStep(
            identifier: "b",
            repositoryName: "a-very-long-repository-name-that-needs-to-wrap-somewhere",
            branch: "main",
            action: .blocked(.branchNotAllowed("main")),
            trackedChanges: [],
            selectableUntrackedPaths: [],
            includedUntrackedPaths: [],
            outstandingBranches: [],
            submoduleChanges: []
        ),
        toggleUntracked: { _ in },
        isSelected: { _ in false }
    )
    .padding()
    .frame(width: 560)
}
#endif
