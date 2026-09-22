//
//  ExecuteTests.swift
//  homerun
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

import Testing
@testable import homerun

struct ExecuteTests {
    let config = Config(repos: [
        RepoEntry(repoPath: "/usr/bin", wipName: "WIP", main: false),
        RepoEntry(repoPath: "/usr/lib", wipName: "WIP", main: false),
    ])

    func perform(_ arguments: [String], git: FakeGitClient, confirm: Bool = true, tty: Bool = true) throws -> Int32 {
        let command = try Homerun.parseAsRoot(arguments) as! any HomerunCommand
        return try command.perform(git: git, store: FakeConfigStore(config: config), confirmer: FakeConfirmer(answer: confirm), stdinIsTTY: tty)
    }

    @Test func noUpstreamPushesWithSetUpstream() throws {
        let git = FakeGitClient(["/usr/bin": .init(branch: "topic", status: ["M a"], upstream: nil), "/usr/lib": .init()])
        #expect(try perform(["--yolo"], git: git) == 0)
        #expect(git.calls == ["stageAll /usr/bin", "commit /usr/bin", "push /usr/bin topic -u"])
    }

    @Test func onlyAheadDoesNotCommit() throws {
        let git = FakeGitClient(["/usr/bin": .init(ahead: 2), "/usr/lib": .init()])
        #expect(try perform(["--yolo"], git: git) == 0)
        #expect(git.calls == ["push /usr/bin feat"])
    }

    @Test func oneFailureDoesNotStopOthers() throws {
        let git = FakeGitClient([
            "/usr/bin": .init(status: ["M a"], pushError: "error: failed to push some refs"),
            "/usr/lib": .init(status: ["M b"]),
        ])
        #expect(try perform(["--yolo"], git: git) == 1)
        #expect(git.calls.contains("push /usr/bin feat"))
        #expect(git.calls.contains("push /usr/lib feat"))
    }

    @Test func decliningWritesNothing() throws {
        let git = FakeGitClient(["/usr/bin": .init(status: ["M a"]), "/usr/lib": .init(upstream: nil, ahead: 1)])
        #expect(try perform([], git: git, confirm: false) == 0)
        #expect(git.calls.isEmpty)
    }

    @Test func dryRunAndNonTTYWriteNothing() throws {
        let git = FakeGitClient(["/usr/bin": .init(status: ["M a"]), "/usr/lib": .init()])
        #expect(try perform(["--dry-run"], git: git) == 0)
        #expect(try perform([], git: git, tty: false) == 1)
        #expect(git.calls.isEmpty)
    }

    @Test func everythingPushedNeverPrompts() throws {
        let git = FakeGitClient(["/usr/bin": .init(), "/usr/lib": .init()])
        #expect(try perform([], git: git, confirm: false, tty: false) == 0)
    }

    @Test func bareInvocationRunsTheScanDirectly() throws {
        // Bare `homerun` is the default subcommand (sync), not a help print — a
        // non-TTY stdin with pending work still needs `--yes` to proceed.
        let git = FakeGitClient(["/usr/bin": .init(status: ["M a"]), "/usr/lib": .init()])
        #expect(try perform([], git: git, confirm: false, tty: false) == 1)
        #expect(git.calls.isEmpty)
    }

    @Test func yesWithDryRunIsAnError() {
        #expect(throws: (any Error).self) { try Homerun.parseAsRoot(["--yes", "--dry-run"]) }
    }

    @Test func yoloWithDryRunIsAnError() {
        #expect(throws: (any Error).self) { try Homerun.parseAsRoot(["--yolo", "--dry-run"]) }
    }
}
