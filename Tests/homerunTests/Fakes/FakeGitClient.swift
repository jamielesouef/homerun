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
    }

    var repos: [String: Repo]
    private(set) var calls: [String] = []

    init(_ repos: [String: Repo]) {
        self.repos = repos
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
        if let error = try repo(path).pushError { throw GitError(message: error) }
    }

    private func repo(_ path: String) throws -> Repo {
        guard let repo = repos[path] else { throw GitError(message: "fatal: not a git repository") }
        return repo
    }
}
