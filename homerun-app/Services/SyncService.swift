import Foundation

@MainActor
@Observable
final class SyncService {
    // MARK: - State

    enum Phase: Equatable {
        case idle
        case reviewing(SyncPlan)
        case running(SyncProgress)
        case finished(SyncSummary)
    }

    private(set) var phase: Phase = .idle
    private(set) var untrackedSelections: [String: Set<String>] = [:]

    var reviewPlan: SyncPlan? {
        guard case let .reviewing(plan) = phase else {
            return nil
        }

        return plan
    }

    var isRunningOrFinished: Bool {
        switch phase {
        case .running,
             .finished:
            true
        case .idle,
             .reviewing:
            false
        }
    }

    // MARK: - Private

    private let engine: any RepositorySyncPerforming
    private let repositories: RepositoriesService
    private let settings: SettingsService
    private let clock: any Clocking

    private var runTask: Task<Void, Never>?

    // MARK: - Init

    init(
        engine: any RepositorySyncPerforming,
        repositories: RepositoriesService,
        settings: SettingsService,
        clock: any Clocking
    ) {
        self.engine = engine
        self.repositories = repositories
        self.settings = settings
        self.clock = clock
    }

    // MARK: - Intent

    func review(identifiers: Set<String>?) async {
        let selected = selection(identifiers)
        let plan = SyncPlanUseCase.plan(for: selected, untrackedSelections: untrackedSelections)

        guard settings.preferences.requiresSyncConfirmation else {
            phase = .reviewing(plan)
            await run()
            return
        }

        phase = .reviewing(plan)
    }

    func setUntracked(_ path: String, isSelected: Bool, for identifier: String) {
        guard isUntrackedSelected(path, for: identifier) != isSelected else {
            return
        }

        var paths = untrackedSelections[identifier] ?? []

        if isSelected {
            paths.insert(path)
        } else {
            paths.remove(path)
        }

        untrackedSelections[identifier] = paths
        refreshReview()
    }

    func isUntrackedSelected(_ path: String, for identifier: String) -> Bool {
        untrackedSelections[identifier]?.contains(path) == true
    }

    func cancelReview() {
        guard case .reviewing = phase else {
            return
        }

        phase = .idle
    }

    func dismissSummary() {
        guard case .finished = phase else {
            return
        }

        phase = .idle
    }

    func cancelRun() {
        runTask?.cancel()
        runTask = nil
        phase = .idle
    }

    func run() async {
        guard case let .reviewing(plan) = phase else {
            return
        }

        runTask?.cancel()
        let task = Task { [weak self] in
            guard let self else {
                return
            }

            await execute(plan)
        }
        runTask = task
        await task.value
    }

    // MARK: - Helpers

    private func selection(_ identifiers: Set<String>?) -> [TrackedRepository] {
        guard let identifiers else {
            return repositories.repositories
        }

        return repositories.repositories.filter { identifiers.contains($0.id) }
    }

    private func refreshReview() {
        guard case let .reviewing(plan) = phase else {
            return
        }

        let selected = repositories.repositories.filter { repository in
            plan.steps.contains { $0.identifier == repository.id }
        }

        phase = .reviewing(SyncPlanUseCase.plan(for: selected, untrackedSelections: untrackedSelections))
    }

    private func execute(_ plan: SyncPlan) async {
        let steps = plan.actionableSteps
        var outcomes: [RepositorySyncOutcome] = plan.blockedSteps.map(blockedOutcome)

        phase = .running(SyncProgress(
            total: steps.count,
            completed: 0,
            currentRepositoryName: steps.first?.repositoryName
        ))

        for (index, step) in steps.enumerated() {
            guard Task.isCancelled == false else {
                break
            }

            phase = .running(SyncProgress(
                total: steps.count,
                completed: index,
                currentRepositoryName: step.repositoryName
            ))

            guard let request = request(for: step) else {
                outcomes.append(
                    RepositorySyncOutcome(
                        identifier: step.identifier,
                        result: .failed(.notClonedLocally),
                        finishedAt: clock.now()
                    )
                )
                continue
            }

            let report = await engine.sync(request)
            outcomes.append(report.outcome(finishedAt: clock.now()))
        }

        phase = .running(SyncProgress(total: steps.count, completed: steps.count, currentRepositoryName: nil))
        await repositories.apply(outcomes)
        phase = .finished(SyncSummary(outcomes: outcomes))
    }

    private func blockedOutcome(_ step: SyncPlanStep) -> RepositorySyncOutcome {
        guard case let .blocked(failure) = step.action else {
            return RepositorySyncOutcome(
                identifier: step.identifier,
                result: .skipped(String(localized: "Already up to date")),
                finishedAt: clock.now()
            )
        }

        return RepositorySyncOutcome(identifier: step.identifier, result: .failed(failure), finishedAt: clock.now())
    }

    private func request(for step: SyncPlanStep) -> RepositorySyncRequest? {
        guard case let .commitAndPush(willCommit, setsUpstream) = step.action,
              let repository = repositories.repository(identifier: step.identifier),
              let directory = repository.localPath,
              let branch = step.branch,
              let remote = repository.snapshot?.defaultRemoteName
        else {
            return nil
        }

        return RepositorySyncRequest(
            identifier: step.identifier,
            directory: directory,
            branch: branch,
            protectedBranchFallback: ProtectedBranchFallbackUseCase.branchName(
                for: branch,
                timestamp: clock.now(),
                timeZone: clock.timeZone
            ),
            remote: remote,
            remoteURL: repository.snapshot?.remoteURL,
            setsUpstream: setsUpstream,
            willCommit: willCommit,
            untrackedPathsToInclude: step.includedUntrackedPaths,
            commitMessage: WIPCommitMessageUseCase.message(
                repositoryOverride: repository.shared.wipCommitPrefixOverride,
                appWide: settings.preferences.wipCommitPrefix,
                timestamp: clock.now(),
                timeZone: clock.timeZone,
                appendsTimestamp: WIPCommitMessageUseCase.appendsTimestamp(
                    appWide: settings.preferences.appendsTimestampToWIPCommit,
                    repositoryOmits: repository.shared.omitsTimestampFromWIPCommit
                )
            ),
            preferredAccount: repository.shared.preferredGitHubAccount,
            checksAccountAccess: settings.preferences.accountAccessChecksEnabled,
            fallbackEnabled: settings.preferences.accountFallbackEnabled
        )
    }
}
