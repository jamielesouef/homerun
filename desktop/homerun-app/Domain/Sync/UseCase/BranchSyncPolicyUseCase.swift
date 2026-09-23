import Foundation

enum BranchSyncPolicyUseCase {
    static let protectedBranchNames = ["main", "master"]

    static func blockedReason(branch: String?, repository: WorkspaceRepository) -> SyncFailure? {
        guard let branch else {
            return .detachedHead
        }

        switch branch {
        case "main" where repository.allowsMainBranchSync == false:
            return .branchNotAllowed(branch)
        case "master" where repository.allowsMasterBranchSync == false:
            return .branchNotAllowed(branch)
        default:
            return nil
        }
    }
}
