//
//  GitClient.swift
//  homerun
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

protocol GitClient: Sendable {
    func isRepo(at path: String) -> Bool
    // nil means detached HEAD.
    func currentBranch(at path: String) throws -> String?
    // One line per change, as `git status --porcelain` prints it.
    func porcelainStatus(at path: String) throws -> [String]
    // nil means the branch has no upstream.
    func upstream(at path: String) throws -> String?
    // Only meaningful when `upstream` is non-nil.
    func aheadCount(at path: String) throws -> Int
    func stageAll(at path: String) throws
    func commit(at path: String, message: String) throws
    func push(at path: String, branch: String, setUpstream: Bool) throws
}
