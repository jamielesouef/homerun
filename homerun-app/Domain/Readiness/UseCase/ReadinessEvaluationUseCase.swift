import Foundation

enum ReadinessEvaluationUseCase {
    static func report(
        identifier: String,
        snapshot: GitRepositorySnapshot,
        repository: WorkspaceRepository,
        unpushedTags: [String],
        missingConfigurationTemplates: [String],
        hasSetupInstructions: Bool
    ) -> ReadinessReport {
        var issues: [ReadinessIssue] = []

        if snapshot.isDetached {
            issues.append(.detachedHead)
        }

        if snapshot.hasRemote == false {
            issues.append(.noRemote)
        }

        if snapshot.isDiverged {
            issues.append(.divergedBranch)
        } else if snapshot.aheadCount > 0 {
            issues.append(.currentBranchNotPushed(snapshot.aheadCount))
        }

        if snapshot.workingTree.trackedChanges.isEmpty == false {
            issues.append(.uncommittedChanges(snapshot.workingTree.trackedChanges.count))
        }

        if snapshot.workingTree.untrackedPaths.isEmpty == false {
            issues.append(.untrackedFiles(snapshot.workingTree.untrackedPaths))
        }

        let outstanding = snapshot.otherBranchesNeedingPush
        let localOnly = outstanding.filter(\.isLocalOnly).map(\.name)
        let unpushed = outstanding.filter { $0.isLocalOnly == false && $0.hasUnpushedCommits }.map(\.name)

        if localOnly.isEmpty == false {
            issues.append(.localOnlyBranches(localOnly))
        }

        if unpushed.isEmpty == false {
            issues.append(.unpushedBranchCommits(unpushed))
        }

        if unpushedTags.isEmpty == false {
            issues.append(.unpushedTags(unpushedTags))
        }

        if snapshot.submoduleChanges.isEmpty == false {
            issues.append(.submoduleChanges(snapshot.submoduleChanges.map(\.path)))
        }

        if hasSetupInstructions == false {
            issues.append(.missingSetupInstructions)
        }

        if missingConfigurationTemplates.isEmpty == false {
            issues.append(.missingConfigurationTemplates(missingConfigurationTemplates))
        }

        if repository.requiredEnvironmentVariableNames.isEmpty == false {
            issues.append(.requiredEnvironmentVariables(repository.requiredEnvironmentVariableNames))
        }

        return ReadinessReport(
            identifier: identifier,
            currentBranchPushed: snapshot.isDiverged == false && snapshot.aheadCount == 0 && snapshot.isDetached == false,
            issues: issues
        )
    }
}
