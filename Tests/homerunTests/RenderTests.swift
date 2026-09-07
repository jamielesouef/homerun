//  RenderTests.swift
//  homerun
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

import Testing
@testable import homerun

struct RenderTests {
    func plan(_ name: String, branch: String? = "feat", _ status: RepoStatus) -> RepoPlan {
        RepoPlan(entry: RepoEntry(repoPath: "~/dev/\(name)", wipName: "WIP", main: false), branch: branch, status: status)
    }

    @Test func planRowsAreAlignedPlainText() {
        let plans = [
            plan("kick-tvos", branch: "feat-player", .needsPush(changed: 4, ahead: 1, upstream: "origin/feat-player")),
            plan("homerun", branch: "main", .needsPush(changed: 2, ahead: nil, upstream: nil)),
            plan("dotfiles", .skipped(reason: "on main, main: false")),
            plan("kick-ios", .clean),
        ]
        let rows = Row.render(plans: plans)
        #expect(rows.map(\.text) == [
            "  ↑  kick-tvos  4 changed, 1 ahead      push → origin/feat-player",
            "  ↑  homerun    2 changed, no upstream  push → origin/main (-u)",
            "  ⊘  dotfiles   on main, main: false    skip",
            "  ✓  kick-ios   clean",
        ])
        #expect(rows.map(\.kind) == [.pending, .pending, .pending, .clean])
        #expect(Row.summary(plans: plans) == "2 to push · 1 skipped · 1 clean")
        #expect(rows.allSatisfy { Style.apply($0, colour: false) == $0.text })
    }

    @Test func resultRowsAndSummary() {
        let results = [
            RepoResult(plan: plan("kick-tvos", .clean), outcome: .pushed(target: "origin/feat-player")),
            RepoResult(plan: plan("dotfiles", .clean), outcome: .skipped),
            RepoResult(plan: plan("scratch", .clean), outcome: .failed("push rejected (non-fast-forward)")),
        ]
        let rows = Row.render(results: results)
        #expect(rows.map(\.text) == [
            "  ✓  kick-tvos  pushed → origin/feat-player",
            "  ⊘  dotfiles   skipped",
            "  ✗  scratch    push rejected (non-fast-forward)",
        ])
        #expect(rows.map(\.kind) == [.pushed, .pending, .failed])
        #expect(Row.summary(results: results) == "1 pushed · 1 skipped · 1 failed")
    }

    @Test func colourWrapsOnlyWhenEnabled() {
        let row = Row(text: "  ✓  x  pushed", kind: .pushed)
        #expect(Style.apply(row, colour: true) == "\u{1b}[32m  ✓  x  pushed\u{1b}[0m")
        #expect(Style.apply(row, colour: false) == "  ✓  x  pushed")
    }
}
