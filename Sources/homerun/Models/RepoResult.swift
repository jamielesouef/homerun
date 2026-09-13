//
//  RepoResult.swift
//  homerun
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

import Foundation

struct RepoResult: Equatable, Sendable {
    enum Outcome: Equatable, Sendable {
        case pushed(target: String)
        // `account` is the gh account the push finally succeeded under, when a
        // switch was needed; nil means it went through on the active account.
        case pushedAfterSwitch(target: String, account: String)
        case skipped
        case failed(String)
    }

    var plan: RepoPlan
    var outcome: Outcome
}

extension RepoResult {
    // Clean repos are not acted on, so they do not appear in the result.
    // `progress` fires as each repo starts and finishes, so a long run is legible.
    // `auth`, when present, lets a permission-denied push retry under another
    // `gh` account; the original active account is always restored afterwards.
    static func execute(
        _ plans: [RepoPlan],
        git: any GitClient,
        auth: (any GitHubAuth)? = nil,
        now: Date = .now,
        progress: (Progress) -> Void = { _ in }
    ) -> [RepoResult] {
        let originalAccount = auth?.activeAccount()
        defer {
            if let auth, let originalAccount, auth.activeAccount() != originalAccount {
                try? auth.switchTo(account: originalAccount)
            }
        }
        return plans.compactMap { plan in
            switch plan.status {
            case .clean:
                return nil
            case .skipped:
                return RepoResult(plan: plan, outcome: .skipped)
            case .failed(let reason):
                return RepoResult(plan: plan, outcome: .failed(reason))
            case .needsPush(let changed, _, let upstream):
                progress(.started(name: plan.entry.name))
                let result = push(plan, changed: changed, upstream: upstream, git: git, auth: auth, now: now, progress: progress)
                progress(.finished(result))
                return result
            }
        }
    }

    enum Progress {
        case started(name: String)
        case switchingAccount(name: String, account: String)
        case finished(RepoResult)
    }

    private static func push(
        _ plan: RepoPlan, changed: Int, upstream: String?, git: any GitClient,
        auth: (any GitHubAuth)?, now: Date, progress: (Progress) -> Void
    ) -> RepoResult {
        guard let branch = plan.branch else {
            return RepoResult(plan: plan, outcome: .failed("no branch"))
        }
        let path = plan.entry.expandedPath
        do {
            // A repo that is merely ahead has nothing to commit; git would refuse.
            if changed > 0 {
                try git.stageAll(at: path)
                try git.commit(at: path, message: "\(plan.entry.wipName): \(now.formatted(.iso8601))")
            }
            return try pushWithAuthRetry(plan, branch: branch, path: path, upstream: upstream, git: git, auth: auth, progress: progress)
        } catch {
            return RepoResult(plan: plan, outcome: .failed(GitError.describe(error)))
        }
    }

    // Push on the active account; on an auth failure, walk the other gh accounts
    // and retry, reporting which one finally worked.
    private static func pushWithAuthRetry(
        _ plan: RepoPlan, branch: String, path: String, upstream: String?,
        git: any GitClient, auth: (any GitHubAuth)?, progress: (Progress) -> Void
    ) throws -> RepoResult {
        let target = upstream ?? "origin/\(branch) (-u)"
        do {
            try git.push(at: path, branch: branch, setUpstream: upstream == nil)
            return RepoResult(plan: plan, outcome: .pushed(target: target))
        } catch let error as GitError where error.isAuthFailure {
            guard let auth, auth.isAvailable else { throw error }
            let active = auth.activeAccount()
            let candidates = auth.accounts().filter { $0 != active }
            for account in candidates {
                progress(.switchingAccount(name: plan.entry.name, account: account))
                guard (try? auth.switchTo(account: account)) != nil else { continue }
                do {
                    try git.push(at: path, branch: branch, setUpstream: upstream == nil)
                    return RepoResult(plan: plan, outcome: .pushedAfterSwitch(target: target, account: account))
                } catch let retry as GitError where retry.isAuthFailure {
                    continue
                }
            }
            throw error
        }
    }
}
