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

    var id: String {
        identifier
    }

    var isActionable: Bool {
        action.isActionable
    }
}
