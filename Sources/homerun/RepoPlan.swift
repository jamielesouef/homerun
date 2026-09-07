//  RepoPlan.swift
//  homerun
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

import Foundation

struct RepoPlan: Equatable, Sendable {
    var entry: RepoEntry
    var branch: String?
    var status: RepoStatus
}

extension RepoPlan {
    static func scan(_ entries: [RepoEntry], git: any GitClient) -> [RepoPlan] {
        entries.map { scan($0, git: git) }
    }

    static func scan(_ entry: RepoEntry, git: any GitClient) -> RepoPlan {
        let path = entry.expandedPath
        guard FileManager.default.fileExists(atPath: path) else {
            return RepoPlan(entry: entry, branch: nil, status: .failed("path not found"))
        }
        guard git.isRepo(at: path) else {
            return RepoPlan(entry: entry, branch: nil, status: .failed("not a git repo"))
        }
        do {
            guard let branch = try git.currentBranch(at: path) else {
                return RepoPlan(entry: entry, branch: nil, status: .skipped(reason: "detached HEAD"))
            }
            return RepoPlan(entry: entry, branch: branch, status: try status(of: entry, branch: branch, git: git))
        } catch {
            return RepoPlan(entry: entry, branch: nil, status: .failed(GitError.describe(error)))
        }
    }

    private static func status(of entry: RepoEntry, branch: String, git: any GitClient) throws -> RepoStatus {
        if !entry.main, branch == "main" || branch == "master" {
            return .skipped(reason: "on \(branch), main: false")
        }
        let path = entry.expandedPath
        let changed = try git.porcelainStatus(at: path).count
        let upstream = try git.upstream(at: path)
        let ahead = try upstream.map { _ in try git.aheadCount(at: path) }
        if changed == 0, ahead == 0 {
            return .clean
        }
        return .needsPush(changed: changed, ahead: ahead, upstream: upstream)
    }
}
