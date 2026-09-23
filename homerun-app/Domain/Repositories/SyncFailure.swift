import Foundation

enum SyncFailure: Error, Equatable {
    case authentication(String)
    case diverged
    case noRemote
    case noUpstream
    case branchNotAllowed(String)
    case detachedHead
    case notClonedLocally
    case accountAccessDenied(String)
    case git(String)

    var message: String {
        switch self {
        case .authentication(let detail):
            String(localized: "Authentication failed: \(detail)")
        case .diverged:
            String(localized: "The branch has diverged from its remote. Resolve it by hand.")
        case .noRemote:
            String(localized: "No push destination is configured.")
        case .noUpstream:
            String(localized: "The branch has no upstream yet.")
        case .branchNotAllowed(let branch):
            String(localized: "Syncing \(branch) is turned off for this repository.")
        case .detachedHead:
            String(localized: "HEAD is detached, so there is no branch to push.")
        case .notClonedLocally:
            String(localized: "This repository is not cloned on this Mac.")
        case .accountAccessDenied(let account):
            String(localized: "The account \(account) cannot reach this repository.")
        case .git(let detail):
            detail
        }
    }
}
