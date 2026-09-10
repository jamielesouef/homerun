//
//  FakeGitClient.swift
//  homerun
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

@testable import homerun

// Tests drive this on one thread; the lock-free `@unchecked Sendable` is deliberate.
final class FakeGitClient: GitClient, @unchecked Sendable {
    struct Repo {
        var branch: String? = "feat"
        var status: [String] = []
        var upstream: String? = "origin/feat"
        var ahead = 0
        var pushError: String?
        // When set, push fails with a permission error unless `auth`'s active
        // account matches this — the multi-account gh-switch scenario.
        var requiredAccount: String?
    }

    var repos: [String: Repo]
    private(set) var calls: [String] = []
    // Optional link to the auth fake so a push can consult the active account.
    var auth: FakeGitHubAuth?

    init(_ repos: [String: Repo], auth: FakeGitHubAuth? = nil) {
        self.repos = repos
        self.auth = auth
    }

    func isRepo(at path: String) -> Bool { repos[path] != nil }

    func currentBranch(at path: String) throws -> String? { try repo(path).branch }

    func porcelainStatus(at path: String) throws -> [String] { try repo(path).status }

    func upstream(at path: String) throws -> String? { try repo(path).upstream }

    func aheadCount(at path: String) throws -> Int { try repo(path).ahead }

    func stageAll(at path: String) throws { calls.append("stageAll \(path)") }

    func commit(at path: String, message: String) throws { calls.append("commit \(path)") }

    func push(at path: String, branch: String, setUpstream: Bool) throws {
        calls.append("push \(path) \(branch)\(setUpstream ? " -u" : "")")
        let repo = try repo(path)
        if let required = repo.requiredAccount, auth?.activeAccount() != required {
            throw GitError(message: "remote: Permission denied to this repository")
        }
        if let error = repo.pushError { throw GitError(message: error) }
    }

    private func repo(_ path: String) throws -> Repo {
        guard let repo = repos[path] else { throw GitError(message: "fatal: not a git repository") }
        return repo
    }
}
