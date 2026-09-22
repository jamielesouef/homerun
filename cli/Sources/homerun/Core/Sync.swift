//
//  Sync.swift
//  homerun
//
//  Created by Jamie Le Souëf on 13/09/2026.
//

import Foundation

// The default action: scan every tracked repo, show the plan, confirm, push.
struct Sync {
    var repo: [String]
    var dryRun: Bool
    var yolo: Bool

    func run(
        git: any GitClient, store: any ConfigStore, confirmer: any Confirmer,
        auth: (any GitHubAuth)?, stdinIsTTY: Bool, showProgress: Bool
    ) throws -> Int32 {
        guard let config = try store.load(), !config.repos.isEmpty else {
            print("📭 No repos configured. Add one with \"homerun add <path>\".")
            return 0
        }
        guard let entries = try filtered(config.repos) else { return 1 }
        if showProgress {
            print("Scanning \(entries.count) \(entries.count == 1 ? "repo" : "repos")...")
        }
        let plans = entries.map { entry -> RepoPlan in
            if showProgress { print(Style.paint("  … \(entry.name)", "2")) }
            return RepoPlan.scan(entry, git: git)
        }
        let pending = plans.filter(\.status.needsPush)
        let scanFailed = plans.contains(where: \.status.isFailed)
        if pending.isEmpty, !scanFailed {
            print("Everything is pushed.")
            return 0
        }
        print("Scanning \(plans.count) \(plans.count == 1 ? "repo" : "repos")\n")
        Row.render(plans: plans).forEach { print(Style.apply($0)) }
        print("\n\(Row.summary(plans: plans))")
        if dryRun || pending.isEmpty { return scanFailed ? 1 : 0 }
        if !yolo {
            guard stdinIsTTY else {
                print("Not a TTY — pass --yes to run unattended.")
                return 1
            }
            print()
            guard confirmer.confirm(prompt: "Continue? [y/N] ") else {
                print("Cancelled. Nothing was changed.")
                return 0
            }
        }
        if showProgress { print() }
        let results = RepoResult.execute(plans, git: git, auth: auth) { event in
            guard showProgress else { return }
            switch event {
            case .started(let name):
                print(Style.paint("  ↑ \(name)…", "2"))
            case .switchingAccount(let name, let account):
                print(Style.paint("    ↺ \(name): retrying as \(account)", "33"))
            case .finished:
                break
            }
        }
        print()
        Row.render(results: results).forEach { print(Style.apply($0)) }
        print("\n\(Row.summary(results: results))")
        let failed = results.contains { if case .failed = $0.outcome { true } else { false } }
        return failed ? 1 : 0
    }

    // nil means a `--repo` path was not in the config; the error has already been printed.
    private func filtered(_ entries: [RepoEntry]) throws -> [RepoEntry]? {
        guard !repo.isEmpty else { return entries }
        let wanted = repo.map { RepoEntry(repoPath: $0, wipName: "", main: false).canonicalPath }
        let known = Set(entries.map(\.canonicalPath))
        for (path, key) in zip(repo, wanted) where !known.contains(key) {
            print(Style.paint("❌ \(path) is not in the config. Add it with \"homerun add\".", "31"))
            return nil
        }
        return entries.filter { wanted.contains($0.canonicalPath) }
    }
}
