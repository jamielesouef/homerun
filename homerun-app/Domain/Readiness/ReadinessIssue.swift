import Foundation

enum ReadinessIssue: Equatable, Identifiable {
    case detachedHead
    case noRemote
    case currentBranchNotPushed(Int)
    case divergedBranch
    case uncommittedChanges(Int)
    case untrackedFiles([String])
    case localOnlyBranches([String])
    case unpushedBranchCommits([String])
    case unpushedTags([String])
    case submoduleChanges([String])
    case missingSetupInstructions
    case missingConfigurationTemplates([String])
    case requiredEnvironmentVariables([String])

    var id: String {
        title
    }

    var title: String {
        switch self {
        case .detachedHead:
            String(localized: "HEAD is detached")
        case .noRemote:
            String(localized: "No push destination")
        case .currentBranchNotPushed:
            String(localized: "Current branch not pushed")
        case .divergedBranch:
            String(localized: "Branch diverged from its remote")
        case .uncommittedChanges:
            String(localized: "Uncommitted changes")
        case .untrackedFiles:
            String(localized: "Untracked files")
        case .localOnlyBranches:
            String(localized: "Branches that exist only here")
        case .unpushedBranchCommits:
            String(localized: "Branches with unpushed commits")
        case .unpushedTags:
            String(localized: "Tags that exist only here")
        case .submoduleChanges:
            String(localized: "Submodules need attention")
        case .missingSetupInstructions:
            String(localized: "No setup instructions recorded")
        case .missingConfigurationTemplates:
            String(localized: "Missing local configuration templates")
        case .requiredEnvironmentVariables:
            String(localized: "Environment variables to set")
        }
    }

    var explanation: String {
        switch self {
        case .detachedHead:
            String(localized: "There is no branch to push, so the other Mac has nothing to check out.")
        case .noRemote:
            String(localized: "Nothing here can reach another Mac until a remote is configured.")
        case .currentBranchNotPushed(let count):
            String(localized: "\(count) commit(s) on the current branch exist only on this Mac.")
        case .divergedBranch:
            String(localized: "The branch and its remote have both moved on. Resolve it here before handing over.")
        case .uncommittedChanges(let count):
            String(localized: "\(count) tracked file(s) have changes that are not committed yet.")
        case .untrackedFiles(let paths):
            String(localized: "These files are not in git and will not travel: \(paths.joined(separator: ", ")).")
        case .localOnlyBranches(let names):
            String(localized: "These branches have never been pushed: \(names.joined(separator: ", ")).")
        case .unpushedBranchCommits(let names):
            String(localized: "These branches have commits that exist only here: \(names.joined(separator: ", ")).")
        case .unpushedTags(let names):
            String(localized: "These tags have not been pushed: \(names.joined(separator: ", ")).")
        case .submoduleChanges(let paths):
            String(localized: "These submodules differ from their recorded commit: \(paths.joined(separator: ", ")).")
        case .missingSetupInstructions:
            String(localized: "The manifest records no setup instructions, so another Mac has nothing to follow.")
        case .missingConfigurationTemplates(let paths):
            String(localized: "The manifest expects these configuration templates, which are not in the repository: \(paths.joined(separator: ", ")).")
        case .requiredEnvironmentVariables(let names):
            String(localized: "These environment variables must be set by hand on the other Mac: \(names.joined(separator: ", ")). Their values are never copied.")
        }
    }
}
