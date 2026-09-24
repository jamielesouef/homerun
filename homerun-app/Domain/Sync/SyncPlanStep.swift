import Foundation

struct SyncPlanStep: Equatable, Identifiable {
    let identifier: String
    let repositoryName: String
    let branch: String?
    let action: SyncPlanAction
    let trackedChanges: [GitFileChange]
    let selectableUntrackedPaths: [String]
    let includedUntrackedPaths: [String]
    let outstandingBranches: [GitBranchRef]
    let submoduleChanges: [GitSubmoduleChange]
    var worktreeName: String?

    var id: String {
        identifier
    }

    var displayName: String {
        guard let worktreeName else {
            return repositoryName
        }

        return String(localized: "\(repositoryName) › \(worktreeName)")
    }

    var isActionable: Bool {
        action.isActionable
    }
}
