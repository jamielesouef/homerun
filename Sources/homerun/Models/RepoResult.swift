//  RepoResult.swift
//  homerun
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

import Foundation

struct RepoResult: Equatable, Sendable {
    enum Outcome: Equatable, Sendable {
        case pushed(target: String)
        case skipped
        case failed(String)
    }

    var plan: RepoPlan
    var outcome: Outcome
}

extension RepoResult {
    // Clean repos are not acted on, so they do not appear in the result.
    static func execute(_ plans: [RepoPlan], git: any GitClient, now: Date = .now) -> [RepoResult] {
        plans.compactMap { plan in
            switch plan.status {
            case .clean:
                return nil
            case .skipped:
                return RepoResult(plan: plan, outcome: .skipped)
            case .failed(let reason):
                return RepoResult(plan: plan, outcome: .failed(reason))
            case .needsPush(let changed, _, let upstream):
                return push(plan, changed: changed, upstream: upstream, git: git, now: now)
            }
        }
    }

    private static func push(
        _ plan: RepoPlan, changed: Int, upstream: String?, git: any GitClient, now: Date
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
            try git.push(at: path, branch: branch, setUpstream: upstream == nil)
            let target = upstream ?? "origin/\(branch) (-u)"
            return RepoResult(plan: plan, outcome: .pushed(target: target))
        } catch {
            return RepoResult(plan: plan, outcome: .failed(GitError.describe(error)))
        }
    }
}
