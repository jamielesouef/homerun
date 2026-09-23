import Foundation

struct RepositorySyncEngine: RepositorySyncPerforming {
    // MARK: - Private

    private let gitClient: any GitClienting
    private let gitHubClient: any GitHubCLIClienting
    private let pushFallback: any PushFallbackPerforming

    // MARK: - Init

    init(
        gitClient: any GitClienting,
        gitHubClient: any GitHubCLIClienting,
        pushFallback: any PushFallbackPerforming
    ) {
        self.gitClient = gitClient
        self.gitHubClient = gitHubClient
        self.pushFallback = pushFallback
    }

    // MARK: - RepositorySyncPerforming

    func sync(_ request: RepositorySyncRequest) async -> RepositorySyncReport {
        if let denial = await accessDenial(for: request) {
            return report(request, result: .failed(denial), committed: false)
        }

        guard request.willCommit else {
            return await push(request, committed: false)
        }

        switch await commit(request) {
        case .committed:
            return await push(request, committed: true)
        case .nothingStaged:
            return await push(request, committed: false)
        case .failed(let failure):
            return report(request, result: .failed(failure), committed: false)
        }
    }

    // MARK: - Helpers

    private enum CommitOutcome {
        case committed
        case nothingStaged
        case failed(SyncFailure)
    }

    private func accessDenial(for request: RepositorySyncRequest) async -> SyncFailure? {
        guard request.checksAccountAccess, let remoteURL = request.remoteURL else {
            return nil
        }

        guard AccountFallbackUseCase.appliesToRemote(remoteURL), await gitHubClient.isAvailable() else {
            return nil
        }

        guard await gitHubClient.hasAccess(toRemoteURL: remoteURL) == false else {
            return nil
        }

        let accounts = try? await gitHubClient.accounts()
        let active = accounts.flatMap { AccountFallbackUseCase.accountToRestore(from: $0) }

        return .accountAccessDenied(active ?? request.preferredAccount ?? remoteURL)
    }

    private func commit(_ request: RepositorySyncRequest) async -> CommitOutcome {
        do {
            try await gitClient.stageTrackedChanges(at: request.directory)
            try await gitClient.stage(paths: request.untrackedPathsToInclude, at: request.directory)
            try await gitClient.commit(message: request.commitMessage, at: request.directory)
        } catch {
            guard error != .nothingToCommit else {
                return .nothingStaged
            }

            return .failed(.git(String(describing: error)))
        }

        return .committed
    }

    private func push(_ request: RepositorySyncRequest, committed: Bool) async -> RepositorySyncReport {
        do {
            try await gitClient.push(
                branch: request.branch,
                remote: request.remote,
                setUpstream: request.setsUpstream,
                at: request.directory
            )
        } catch {
            return await handle(error, request: request, committed: committed)
        }

        return report(request, result: .succeeded(commit: await headCommit(request), branch: request.branch), committed: committed)
    }

    private func handle(_ error: GitError, request: RepositorySyncRequest, committed: Bool) async -> RepositorySyncReport {
        switch error {
        case .authenticationFailed(let detail):
            return await retryWithFallback(request, committed: committed, detail: detail)
        case .diverged:
            return report(request, result: .failed(.diverged), committed: committed)
        case .noRemoteConfigured:
            return report(request, result: .failed(.noRemote), committed: committed)
        case .noUpstreamConfigured:
            return report(request, result: .failed(.noUpstream), committed: committed)
        case .gitUnavailable,
             .notARepository,
             .commandFailed,
             .nothingToCommit,
             .cancelled:
            return report(request, result: .failed(.git(String(describing: error))), committed: committed)
        }
    }

    private func retryWithFallback(
        _ request: RepositorySyncRequest,
        committed: Bool,
        detail: String
    ) async -> RepositorySyncReport {
        guard request.fallbackEnabled else {
            return report(request, result: .failed(.authentication(detail)), committed: committed)
        }

        let context = PushAttemptContext(
            directory: request.directory,
            branch: request.branch,
            remote: request.remote,
            remoteURL: request.remoteURL,
            setsUpstream: request.setsUpstream,
            preferredAccount: request.preferredAccount
        )
        let fallback = await pushFallback.retryPush(context)

        switch fallback {
        case .succeeded(let account, _):
            AppLog.info("Pushed \(request.identifier) using the GitHub account \(account)")
            return report(
                request,
                result: .succeeded(commit: await headCommit(request), branch: request.branch),
                committed: committed,
                fallback: fallback
            )
        case .notApplicable,
             .exhausted:
            return report(request, result: .failed(.authentication(detail)), committed: committed, fallback: fallback)
        }
    }

    private func headCommit(_ request: RepositorySyncRequest) async -> String? {
        try? await gitClient.headCommit(at: request.directory)
    }

    private func report(
        _ request: RepositorySyncRequest,
        result: RepositorySyncOutcome.Result,
        committed: Bool,
        fallback: AccountFallbackResult? = nil
    ) -> RepositorySyncReport {
        RepositorySyncReport(
            identifier: request.identifier,
            branch: request.branch,
            result: result,
            fallback: fallback,
            committed: committed
        )
    }
}
