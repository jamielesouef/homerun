//  Homerun.swift
//  homerun
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

import ArgumentParser
import Foundation

@main
struct Homerun: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "WIP-commit and push every tracked repo so work is never stranded on one machine."
    )

    @Flag(name: [.customShort("s"), .long], help: "Scan every tracked repo, show the plan, and push what needs it.")
    var sync = false

    @Flag(name: [.customShort("d"), .long], help: "Show the plan and exit. Never prompts, never writes.")
    var dryRun = false

    @Flag(name: [.customShort("y"), .customLong("yolo"), .customLong("yes")], help: "Skip the prompt and push immediately.")
    var yolo = false

    @Flag(name: [.customShort("l"), .long], help: "List the repos currently tracked in the config.")
    var list = false

    @Flag(name: [.customShort("A"), .long], help: "Remove every repo from the config.")
    var removeAll = false

    @Flag(name: [.customShort("R"), .long], help: "With --add: walk the directory tree and add every git repo found.")
    var recursive = false

    @Option(name: [.customShort("p"), .long], help: "Limit the scan to this configured repo. Repeatable.")
    var repo: [String] = []

    @Option(name: [.customShort("a"), .customLong("add"), .long], help: "Add a repo to the config and exit. \".\" means the current folder.")
    var addPath: String?

    @Option(name: [.customShort("r"), .customLong("remove"), .long], help: "Remove a repo from the config and exit. \".\" means the current folder.")
    var removePath: String?

    @Option(name: [.customShort("m"), .customLong("main")], help: "With --add: push even when the branch is main or master.")
    var allowMain = false

    @Option(name: [.customShort("w"), .customLong("wip-name")], help: "With --add: prefix for the WIP commit message. Defaults to the config default, or \"WIP\".")
    var wipName: String?

    @Option(name: [.customShort("W"), .customLong("default-wip-name")], help: "Set the config-wide default WIP commit prefix and exit.")
    var defaultWipName: String?

    func validate() throws {
        if yolo && dryRun {
            throw ValidationError("--yolo and --dry-run cannot be combined.")
        }
        if recursive && addPath == nil {
            throw ValidationError("--recursive needs --add <path>.")
        }
    }

    func run() async throws {
        let code = try perform(
            git: ProcessGitClient(),
            store: JSONConfigStore(),
            confirmer: ReadLineConfirmer(),
            stdinIsTTY: isatty(STDIN_FILENO) != 0
        )
        if code != 0 { throw ExitCode(code) }
    }

    // The whole decision flow, with every side-effecting dependency injected so tests can drive it.
    func perform(git: any GitClient, store: any ConfigStore, confirmer: any Confirmer, stdinIsTTY: Bool) throws -> Int32 {
        if let defaultWipName { return try setDefaultWipName(defaultWipName, store: store) }
        if let addPath { return try add(addPath, git: git, store: store) }
        if let removePath { return try remove(removePath, store: store) }
        if removeAll { return try removeAllRepos(store: store) }
        if list { return try printList(store: store) }
        guard sync || dryRun else {
            print(Self.helpMessage())
            return 0
        }
        return try runSync(git: git, store: store, confirmer: confirmer, stdinIsTTY: stdinIsTTY)
    }

    private func runSync(git: any GitClient, store: any ConfigStore, confirmer: any Confirmer, stdinIsTTY: Bool) throws -> Int32 {
        guard let config = try store.load(), !config.repos.isEmpty else {
            print("No repos configured. Add one with --add <path>.")
            return 0
        }
        guard let entries = try filtered(config.repos) else { return 1 }
        let plans = RepoPlan.scan(entries, git: git)
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
            guard confirmer.confirm() else {
                print("Cancelled. Nothing was changed.")
                return 0
            }
        }
        let results = RepoResult.execute(plans, git: git)
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
            print("error: \(path) is not in the config. Add it with --add.")
            return nil
        }
        return entries.filter { wanted.contains($0.canonicalPath) }
    }

    private func add(_ rawPath: String, git: any GitClient, store: any ConfigStore) throws -> Int32 {
        let path = resolved(rawPath)
        var config = try store.load() ?? Config()
        let wip = wipName ?? config.defaultWipName ?? "WIP"

        if recursive {
            let root = NSString(string: path).expandingTildeInPath
            let found = Self.findRepos(in: root, git: git)
            guard !found.isEmpty else {
                print("error: no git repos found under \(path).")
                return 1
            }
            for repoPath in found {
                config.upsert(RepoEntry(repoPath: repoPath, wipName: wip, main: allowMain))
            }
            try store.save(config)
            print("Added \(found.count) repo\(found.count == 1 ? "" : "s") under \(path)")
            return 0
        }

        let entry = RepoEntry(repoPath: path, wipName: wip, main: allowMain)
        guard git.isRepo(at: entry.expandedPath) else {
            print("error: \(path) is not a git repo.")
            return 1
        }
        config.upsert(entry)
        try store.save(config)
        print("Added \(path)")
        return 0
    }

    private func remove(_ rawPath: String, store: any ConfigStore) throws -> Int32 {
        let path = resolved(rawPath)
        var config = try store.load() ?? Config()
        guard config.remove(path: path) else {
            print("error: \(path) is not in the config.")
            return 1
        }
        try store.save(config)
        print("Removed \(path)")
        return 0
    }

    private func removeAllRepos(store: any ConfigStore) throws -> Int32 {
        var config = try store.load() ?? Config()
        let count = config.repos.count
        config.repos.removeAll()
        try store.save(config)
        print("Removed \(count) repo\(count == 1 ? "" : "s").")
        return 0
    }

    private func printList(store: any ConfigStore) throws -> Int32 {
        let config = try store.load() ?? Config()
        guard !config.repos.isEmpty else {
            print("No repos configured. Add one with --add <path>.")
            return 0
        }
        for entry in config.repos {
            print("  \(entry.repoPath)  (wip: \(entry.wipName), main: \(entry.main))")
        }
        return 0
    }

    private func setDefaultWipName(_ name: String, store: any ConfigStore) throws -> Int32 {
        var config = try store.load() ?? Config()
        config.defaultWipName = name
        try store.save(config)
        print("Default WIP name set to \(name)")
        return 0
    }

    private func resolved(_ path: String) -> String {
        path == "." ? FileManager.default.currentDirectoryPath : path
    }

    // Descends until it finds a repo, then stops — nested/submodule repos below it are not walked.
    // ponytail: follows symlinked directories as-is; a symlink cycle would loop forever.
    private static func findRepos(in root: String, git: any GitClient) -> [String] {
        if git.isRepo(at: root) { return [root] }
        guard let children = try? FileManager.default.contentsOfDirectory(atPath: root) else { return [] }
        var found: [String] = []
        for child in children where child != ".git" {
            let path = root + "/" + child
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else { continue }
            found += findRepos(in: path, git: git)
        }
        return found
    }
}
