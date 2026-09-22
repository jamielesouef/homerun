//
//  AuthSwitchTests.swift
//  homerun
//
//  Created by Jamie Le Souëf on 10/09/2026.
//

import Foundation
import Testing
@testable import homerun

// The gh-account-switch retry path in RepoResult.execute, driven entirely by
// fakes: a repo that only pushes under a second account, with the original
// active account restored afterwards.
struct AuthSwitchTests {
    func plan(_ path: String, requiredAccount: String? = nil) -> RepoPlan {
        RepoPlan(
            entry: RepoEntry(repoPath: path, wipName: "WIP", main: false),
            branch: "feat",
            status: .needsPush(changed: 1, ahead: 0, upstream: "origin/feat"))
    }

    @Test func switchesAccountWhenTheActiveOneCannotPush() {
        let auth = FakeGitHubAuth(active: "work", all: ["work", "personal"])
        let git = FakeGitClient(["/a": .init(status: ["M a"], requiredAccount: "personal")], auth: auth)
        let results = RepoResult.execute([plan("/a")], git: git, auth: auth)
        #expect(results.first?.outcome == .pushedAfterSwitch(target: "origin/feat", account: "personal"))
        #expect(auth.switches.contains("personal"))
    }

    @Test func restoresTheOriginalActiveAccountAfterwards() {
        let auth = FakeGitHubAuth(active: "work", all: ["work", "personal"])
        let git = FakeGitClient(["/a": .init(status: ["M a"], requiredAccount: "personal")], auth: auth)
        _ = RepoResult.execute([plan("/a")], git: git, auth: auth)
        #expect(auth.activeAccount() == "work")
    }

    @Test func doesNotSwitchWhenTheActiveAccountCanPush() {
        let auth = FakeGitHubAuth(active: "work", all: ["work", "personal"])
        let git = FakeGitClient(["/a": .init(status: ["M a"], requiredAccount: "work")], auth: auth)
        let results = RepoResult.execute([plan("/a")], git: git, auth: auth)
        #expect(results.first?.outcome == .pushed(target: "origin/feat"))
        #expect(auth.switches.isEmpty)
    }

    @Test func failsWhenNoAccountCanPush() {
        let auth = FakeGitHubAuth(active: "work", all: ["work", "personal"])
        let git = FakeGitClient(["/a": .init(status: ["M a"], requiredAccount: "nobody")], auth: auth)
        let results = RepoResult.execute([plan("/a")], git: git, auth: auth)
        if case .failed = results.first?.outcome {} else {
            Issue.record("expected a failure when no account can push")
        }
        #expect(auth.activeAccount() == "work")
    }

    @Test func nonAuthFailureNeverTriggersASwitch() {
        let auth = FakeGitHubAuth(active: "work", all: ["work", "personal"])
        let git = FakeGitClient(["/a": .init(status: ["M a"], pushError: "error: failed to push some refs (non-fast-forward)")], auth: auth)
        _ = RepoResult.execute([plan("/a")], git: git, auth: auth)
        #expect(auth.switches.isEmpty)
    }

    @Test func withoutAnAuthHandlerAnAuthFailureJustFails() {
        let git = FakeGitClient(["/a": .init(status: ["M a"], pushError: "remote: Permission denied to this repository")])
        let results = RepoResult.execute([plan("/a")], git: git, auth: nil)
        if case .failed = results.first?.outcome {} else {
            Issue.record("expected a plain failure with no auth handler")
        }
    }

    @Test func progressFiresStartAndFinishPerActedRepo() {
        let git = FakeGitClient(["/a": .init(status: ["M a"]), "/b": .init()])
        var events: [String] = []
        _ = RepoResult.execute([plan("/a"), plan("/b")], git: git) { event in
            switch event {
            case .started(let name): events.append("start \(name)")
            case .switchingAccount: break
            case .finished: events.append("finish")
            }
        }
        #expect(events == ["start a", "finish", "start b", "finish"])
    }
}
