//
//  ScanTests.swift
//  homerun
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

import Testing
@testable import homerun

// Scan checks the path exists on disk before asking git, so fakes are keyed by real directories.
struct ScanTests {
    let entry = RepoEntry(repoPath: "/usr/bin", wipName: "WIP", main: false)

    @Test func dirtyRepoNeedsPush() {
        let git = FakeGitClient(["/usr/bin": .init(status: ["M a", "?? b"])])
        #expect(RepoPlan.scan(entry, git: git).status == .needsPush(changed: 2, ahead: 0, upstream: "origin/feat"))
    }

    @Test func aheadRepoNeedsPush() {
        let git = FakeGitClient(["/usr/bin": .init(ahead: 3)])
        #expect(RepoPlan.scan(entry, git: git).status == .needsPush(changed: 0, ahead: 3, upstream: "origin/feat"))
    }

    @Test func noUpstreamNeedsPush() {
        let git = FakeGitClient(["/usr/bin": .init(upstream: nil)])
        #expect(RepoPlan.scan(entry, git: git).status == .needsPush(changed: 0, ahead: nil, upstream: nil))
    }

    @Test func cleanRepoIsClean() {
        let git = FakeGitClient(["/usr/bin": .init()])
        let plan = RepoPlan.scan(entry, git: git)
        #expect(plan.status == .clean)
        #expect(plan.branch == "feat")
    }

    @Test func mainFalseSkipsMainBranch() {
        let git = FakeGitClient(["/usr/bin": .init(branch: "main", status: ["M a"])])
        #expect(RepoPlan.scan(entry, git: git).status == .skipped(reason: "on main, main: false"))
    }

    @Test func mainTrueDoesNotSkip() {
        let git = FakeGitClient(["/usr/bin": .init(branch: "main", status: ["M a"], upstream: "origin/main")])
        var allowed = entry
        allowed.main = true
        #expect(RepoPlan.scan(allowed, git: git).status == .needsPush(changed: 1, ahead: 0, upstream: "origin/main"))
    }

    @Test func detachedHeadIsSkipped() {
        let git = FakeGitClient(["/usr/bin": .init(branch: nil)])
        #expect(RepoPlan.scan(entry, git: git).status == .skipped(reason: "detached HEAD"))
    }

    @Test func missingPathAndNonRepoFail() {
        let git = FakeGitClient([:])
        #expect(RepoPlan.scan(entry, git: git).status == .failed("not a git repo"))
        let missing = RepoEntry(repoPath: "/nope/nothing", wipName: "WIP", main: false)
        #expect(RepoPlan.scan(missing, git: git).status == .failed("path not found"))
    }
}
