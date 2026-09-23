import Foundation
import Testing
@testable import homerun_app

@Suite("WIPCommitMessageUseCase", .tags(.domain))
struct WIPCommitMessageUseCaseTests {
    @Test("prefers the repository prefix, then the app-wide one, then WIP", arguments: [
        ("SCRATCH", "PARKED", "SCRATCH"),
        (nil, "PARKED", "PARKED"),
        (nil, nil, "WIP"),
        ("  ", "  ", "WIP")
    ])
    func fallsBackThroughThePrefixChain(repository: String?, appWide: String?, expected: String) {
        #expect(WIPCommitMessageUseCase.prefix(repositoryOverride: repository, appWide: appWide) == expected)
    }

    @Test("stamps the message with the time the commit was made")
    func stampsTheTime() throws {
        let timeZone = try #require(TimeZone(identifier: "UTC"))
        let message = WIPCommitMessageUseCase.message(
            repositoryOverride: nil,
            appWide: nil,
            timestamp: Date(timeIntervalSince1970: 1_758_600_000),
            timeZone: timeZone,
            appendsTimestamp: true
        )

        #expect(message == "WIP 2025-09-23 04:00:00")
    }

    @Test("leaves the timestamp off when the setting says not to append it")
    func omitsTheTimestamp() throws {
        let timeZone = try #require(TimeZone(identifier: "UTC"))
        let message = WIPCommitMessageUseCase.message(
            repositoryOverride: "SCRATCH",
            appWide: nil,
            timestamp: Date(timeIntervalSince1970: 1_758_600_000),
            timeZone: timeZone,
            appendsTimestamp: false
        )

        #expect(message == "SCRATCH")
    }
}

@Suite("BranchSyncPolicyUseCase", .tags(.domain))
struct BranchSyncPolicyUseCaseTests {
    @Test("blocks main and master until the repository opts in", arguments: ["main", "master"])
    func blocksProtectedBranches(branch: String) {
        let repository = RepositoryFixtures.shared()

        #expect(BranchSyncPolicyUseCase.blockedReason(branch: branch, repository: repository) == .branchNotAllowed(branch))
    }

    @Test("allows main once the repository opts in")
    func allowsMainWhenOptedIn() {
        let repository = RepositoryFixtures.shared(allowsMain: true)

        #expect(BranchSyncPolicyUseCase.blockedReason(branch: "main", repository: repository) == nil)
    }

    @Test("allows master once the repository opts in")
    func allowsMasterWhenOptedIn() {
        let repository = RepositoryFixtures.shared(allowsMaster: true)

        #expect(BranchSyncPolicyUseCase.blockedReason(branch: "master", repository: repository) == nil)
    }

    @Test("offers a toggle only for the protected branch the repository actually has", arguments: [
        ("main", ["main"]),
        ("master", ["master"]),
        ("trunk", [])
    ])
    func offersOnlyThePresentProtectedBranch(branch: String, expected: [String]) {
        let branches = [GitBranchRef(name: branch, upstream: nil, aheadCount: 0, behindCount: 0)]
        let snapshot = RepositoryFixtures.snapshot(branch: branch, branches: branches)

        #expect(BranchSyncPolicyUseCase.protectedBranchesPresent(in: snapshot) == expected)
    }

    @Test("offers both when the repository has not been read yet")
    func offersBothWhenUnread() {
        #expect(BranchSyncPolicyUseCase.protectedBranchesPresent(in: nil) == ["main", "master"])
    }

    @Test("reads and writes the flag belonging to the branch it was given")
    func readsAndWritesTheRightFlag() {
        var repository = RepositoryFixtures.shared()

        BranchSyncPolicyUseCase.setSyncAllowed(true, branch: "master", in: &repository)

        #expect(repository.allowsMasterBranchSync)
        #expect(repository.allowsMainBranchSync == false)
        #expect(BranchSyncPolicyUseCase.isSyncAllowed(branch: "master", in: repository))
        #expect(BranchSyncPolicyUseCase.isSyncAllowed(branch: "main", in: repository) == false)
    }

    @Test("never blocks an ordinary feature branch")
    func allowsFeatureBranch() {
        #expect(BranchSyncPolicyUseCase.blockedReason(branch: "feature/login", repository: RepositoryFixtures.shared()) == nil)
    }

    @Test("reports a detached head as having no branch to push")
    func reportsDetachedHead() {
        #expect(BranchSyncPolicyUseCase.blockedReason(branch: nil, repository: RepositoryFixtures.shared()) == .detachedHead)
    }
}

@Suite("SyncPlanUseCase", .tags(.domain))
struct SyncPlanUseCaseTests {
    // MARK: - Private

    private func step(_ repository: TrackedRepository, included: Set<String> = []) -> SyncPlanStep {
        SyncPlanUseCase.step(for: repository, includedUntrackedPaths: included)
    }

    // MARK: - Tests

    @Test("plans a WIP commit and push when tracked files have changed")
    func plansCommitAndPush() {
        let repository = RepositoryFixtures.tracked(
            snapshot: RepositoryFixtures.snapshot(branch: "feature/login", tracked: [GitFileChange(path: "A.swift", status: .modified)])
        )

        #expect(step(repository).action == .commitAndPush(willCommit: true, setsUpstream: false))
    }

    @Test("plans a push with no commit when the branch is merely ahead")
    func plansPushOnly() {
        let repository = RepositoryFixtures.tracked(snapshot: RepositoryFixtures.snapshot(branch: "feature/login", ahead: 2))

        #expect(step(repository).action == .commitAndPush(willCommit: false, setsUpstream: false))
    }

    @Test("sets the upstream when the branch has never been pushed")
    func setsUpstreamForNewBranch() {
        let repository = RepositoryFixtures.tracked(snapshot: RepositoryFixtures.snapshot(branch: "spike", upstream: nil))

        #expect(step(repository).action == .commitAndPush(willCommit: false, setsUpstream: true))
    }

    @Test("leaves an already-synced repository alone")
    func leavesSyncedRepositoryAlone() {
        let repository = RepositoryFixtures.tracked(snapshot: RepositoryFixtures.snapshot(branch: "feature/login"))

        #expect(step(repository).action == .nothingToDo)
    }

    @Test("offers untracked files for selection but excludes them until they are chosen")
    func excludesUntrackedUntilChosen() {
        let repository = RepositoryFixtures.tracked(
            snapshot: RepositoryFixtures.snapshot(branch: "feature/login", untracked: ["Notes.md", "Scratch.md"])
        )

        let planned = step(repository)
        #expect(planned.selectableUntrackedPaths == ["Notes.md", "Scratch.md"])
        #expect(planned.includedUntrackedPaths.isEmpty)
        #expect(planned.action == .nothingToDo)
    }

    @Test("commits the untracked files the review explicitly selected")
    func commitsSelectedUntracked() {
        let repository = RepositoryFixtures.tracked(
            snapshot: RepositoryFixtures.snapshot(branch: "feature/login", untracked: ["Notes.md", "Scratch.md"])
        )

        let planned = step(repository, included: ["Notes.md"])
        #expect(planned.includedUntrackedPaths == ["Notes.md"])
        #expect(planned.action == .commitAndPush(willCommit: true, setsUpstream: false))
    }

    @Test("blocks the step rather than force-pushing a diverged branch")
    func blocksDivergedBranch() {
        let repository = RepositoryFixtures.tracked(snapshot: RepositoryFixtures.snapshot(branch: "feature/login", ahead: 1, behind: 1))

        #expect(step(repository).action == .blocked(.diverged))
    }

    @Test("blocks a repository with no push destination")
    func blocksMissingRemote() {
        let repository = RepositoryFixtures.tracked(
            snapshot: RepositoryFixtures.snapshot(branch: "feature/login", remote: nil, upstream: nil)
        )

        #expect(step(repository).action == .blocked(.noRemote))
    }

    @Test("blocks a repository that is not cloned on this Mac")
    func blocksNotCloned() {
        #expect(step(RepositoryFixtures.tracked(path: nil)).action == .blocked(.notClonedLocally))
    }

    @Test("reports submodule changes for attention without blocking the push")
    func reportsSubmodulesWithoutBlocking() {
        let repository = RepositoryFixtures.tracked(
            snapshot: RepositoryFixtures.snapshot(
                branch: "feature/login",
                ahead: 1,
                submodules: [GitSubmoduleChange(path: "Vendor/Lib", kind: .commitDiffers)]
            )
        )

        let planned = step(repository)
        #expect(planned.submoduleChanges.count == 1)
        #expect(planned.isActionable)
    }

    @Test("lists other unsynced branches as outstanding without pushing them")
    func listsOutstandingBranches() {
        let branches = [
            GitBranchRef(name: "feature/login", upstream: "origin/feature/login", aheadCount: 0, behindCount: 0),
            GitBranchRef(name: "spike", upstream: nil, aheadCount: 0, behindCount: 0)
        ]
        let repository = RepositoryFixtures.tracked(
            snapshot: RepositoryFixtures.snapshot(branch: "feature/login", ahead: 1, branches: branches)
        )

        #expect(step(repository).outstandingBranches.map(\.name) == ["spike"])
    }

    @Test("separates the actionable steps from the blocked ones")
    func separatesActionableFromBlocked() {
        let plan = SyncPlanUseCase.plan(
            for: [
                RepositoryFixtures.tracked("a", name: "a", snapshot: RepositoryFixtures.snapshot(branch: "feature/a", ahead: 1)),
                RepositoryFixtures.tracked("b", name: "b", path: nil)
            ],
            untrackedSelections: [:]
        )

        #expect(plan.actionableSteps.map(\.repositoryName) == ["a"])
        #expect(plan.blockedSteps.map(\.repositoryName) == ["b"])
    }
}
