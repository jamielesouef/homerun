import Foundation

enum SyncPlanUseCase {
    static func plan(
        for repositories: [TrackedRepository],
        untrackedSelections: [String: Set<String>]
    ) -> SyncPlan {
        SyncPlan(
            steps: repositories.map { repository in
                step(for: repository, includedUntrackedPaths: untrackedSelections[repository.id] ?? [])
            }
        )
    }

    static func step(for repository: TrackedRepository, includedUntrackedPaths: Set<String>) -> SyncPlanStep {
        let snapshot = repository.snapshot
        let untracked = snapshot?.workingTree.untrackedPaths ?? []
        let included = untracked.filter { includedUntrackedPaths.contains($0) }

        return SyncPlanStep(
            identifier: repository.id,
            repositoryName: repository.name,
            branch: snapshot?.currentBranch,
            action: action(for: repository, includedUntrackedCount: included.count),
            trackedChanges: snapshot?.workingTree.trackedChanges ?? [],
            selectableUntrackedPaths: untracked,
            includedUntrackedPaths: included,
            outstandingBranches: snapshot?.otherBranchesNeedingPush ?? [],
            submoduleChanges: snapshot?.submoduleChanges ?? []
        )
    }

    // MARK: - Helpers

    private static func action(for repository: TrackedRepository, includedUntrackedCount: Int) -> SyncPlanAction {
        guard repository.isCloned else {
            return .blocked(.notClonedLocally)
        }

        if let readError = repository.readError {
            return .blocked(.git(String(describing: readError)))
        }

        guard let snapshot = repository.snapshot else {
            return .blocked(.git(String(localized: "The repository could not be read.")))
        }

        if let reason = BranchSyncPolicyUseCase.blockedReason(branch: snapshot.currentBranch, repository: repository.shared) {
            return .blocked(reason)
        }

        guard snapshot.hasRemote else {
            return .blocked(.noRemote)
        }

        guard snapshot.isDiverged == false else {
            return .blocked(.diverged)
        }

        let willCommit = snapshot.workingTree.hasTrackedChanges || includedUntrackedCount > 0
        let setsUpstream = snapshot.hasUpstream == false

        guard willCommit || setsUpstream || snapshot.aheadCount > 0 else {
            return .nothingToDo
        }

        return .commitAndPush(willCommit: willCommit, setsUpstream: setsUpstream)
    }
}
