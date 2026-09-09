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

    @Flag(name: [.customShort("u"), .long], help: "Remove every tracked repo whose path no longer exists on disk.")
    var purge = false

    @Flag(name: [.customShort("R"), .long], help: "With --add: walk the directory tree and add every git repo found.")
    var recursive = false

    @Option(name: [.customShort("p"), .long], help: "Limit the scan to this configured repo. Repeatable.")
    var repo: [String] = []

    @Option(name: [.customShort("a"), .customLong("add"), .long], help: "Add a repo to the config and exit. \".\" means the current folder.")
    var addPath: String?

    @Option(name: [.customShort("r"), .customLong("remove"), .long], help: "Remove a repo from the config and exit, by its id, its path, or \".\" for the current folder.")
    var removePath: String?

    @Option(name: [.customShort("m"), .customLong("main")], help: "Push even when the branch is main or master. With --add it applies to the repo being added; on its own it updates the repo in the current folder.")
    var allowMain: Bool?

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
        if let allowMain { return try setMain(allowMain, store: store) }
        if removeAll { return try removeAllRepos(store: store, confirmer: confirmer, stdinIsTTY: stdinIsTTY) }
        if purge { return try purgeMissing(git: git, store: store, confirmer: confirmer, stdinIsTTY: stdinIsTTY) }
        if list { return try printList(store: store) }
        guard sync || dryRun else {
            print(Self.helpMessage())
            return 0
        }
        return try runSync(git: git, store: store, confirmer: confirmer, stdinIsTTY: stdinIsTTY)
    }

    private func runSync(git: any GitClient, store: any ConfigStore, confirmer: any Confirmer, stdinIsTTY: Bool) throws -> Int32 {
        guard let config = try store.load(), !config.repos.isEmpty else {
            print("📭 No repos configured. Add one with --add <path>.")
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
            guard confirmer.confirm(prompt: "Continue? [y/N] ") else {
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
            print(Style.paint("❌ \(path) is not in the config. Add it with --add.", "31"))
            return nil
        }
        return entries.filter { wanted.contains($0.canonicalPath) }
    }

    private func add(_ rawPath: String, git: any GitClient, store: any ConfigStore) throws -> Int32 {
        let path = resolved(rawPath)
        if path != rawPath { print("📍 Resolved \"\(rawPath)\" to \(path)") }
        var config = try store.load() ?? Config()
        let wip = wipName ?? config.defaultWipName ?? "WIP"

        if recursive {
            let root = NSString(string: path).expandingTildeInPath
            print("🔎 Walking \(root) for git repos...")
            let found = Self.findRepos(in: root, git: git)
            guard !found.isEmpty else {
                print(Style.paint("❌ No git repos found under \(path).", "31"))
                return 1
            }
            print("📁 Found \(found.count) repo\(found.count == 1 ? "" : "s"):")
            for repoPath in found { print("   " + Style.paint(repoPath, "2")) }
            for repoPath in found {
                config.upsert(RepoEntry(repoPath: repoPath, wipName: wip, main: allowMain ?? false))
            }
            try store.save(config)
            print(Style.paint("✅ Added \(found.count) repo\(found.count == 1 ? "" : "s") under \(path)", "32"))
            return 0
        }

        print("🔍 Checking \(path) is a git repo...")
        let entry = RepoEntry(repoPath: path, wipName: wip, main: allowMain ?? false)
        guard git.isRepo(at: entry.expandedPath) else {
            print(Style.paint("❌ \(path) is not a git repo.", "31"))
            return 1
        }
        config.upsert(entry)
        try store.save(config)
        let id = config.repos.first(where: { $0.canonicalPath == entry.canonicalPath })?.id ?? entry.id
        print(Style.paint("✅ Added \(path)", "32") + "  " + Style.paint("(\(id))", "2"))
        return 0
    }

    // Accepts either a repo's id or its path ("." for the current folder).
    private func remove(_ raw: String, store: any ConfigStore) throws -> Int32 {
        var config = try store.load() ?? Config()

        if let id = UUID(uuidString: raw) {
            let removed = config.repos.first { $0.id == id }
            guard config.remove(id: id) else {
                print(Style.paint("❌ No repo with id \(raw).", "31"))
                return 1
            }
            try store.save(config)
            print(Style.paint("🗑️  Removed \(removed?.repoPath ?? raw)", "32") + "  " + Style.paint("(\(id))", "2"))
            return 0
        }

        let path = resolved(raw)
        guard config.remove(path: path) else {
            print(Style.paint("❌ \(path) is not in the config.", "31"))
            return 1
        }
        try store.save(config)
        print(Style.paint("🗑️  Removed \(path)", "32"))
        return 0
    }

    private func removeAllRepos(store: any ConfigStore, confirmer: any Confirmer, stdinIsTTY: Bool) throws -> Int32 {
        var config = try store.load() ?? Config()
        let count = config.repos.count
        guard count > 0 else {
            print("📭 No repos configured.")
            return 0
        }
        if !yolo {
            guard stdinIsTTY else {
                print(Style.paint("❌ Not a TTY — pass --yes to run unattended.", "31"))
                return 1
            }
            guard confirmer.confirm(prompt: "🗑️  Remove all \(count) repo\(count == 1 ? "" : "s")? [y/N] ") else {
                print("🙅 Cancelled. Nothing was changed.")
                return 0
            }
        }
        config.repos.removeAll()
        try store.save(config)
        print(Style.paint("🗑️  Removed \(count) repo\(count == 1 ? "" : "s").", "32"))
        return 0
    }

    private func purgeMissing(git: any GitClient, store: any ConfigStore, confirmer: any Confirmer, stdinIsTTY: Bool) throws -> Int32 {
        var config = try store.load() ?? Config()
        let missing = config.repos.filter { !git.isRepo(at: $0.expandedPath) }
        guard !missing.isEmpty else {
            print("📭 No missing repos.")
            return 0
        }
        print("👻 \(missing.count) repo\(missing.count == 1 ? "" : "s") no longer on disk:")
        for entry in missing { print("   " + Style.paint(entry.repoPath, "2")) }
        if !yolo {
            guard stdinIsTTY else {
                print(Style.paint("❌ Not a TTY — pass --yes to run unattended.", "31"))
                return 1
            }
            guard confirmer.confirm(prompt: "🗑️  Remove \(missing.count) missing repo\(missing.count == 1 ? "" : "s")? [y/N] ") else {
                print("🙅 Cancelled. Nothing was changed.")
                return 0
            }
        }
        let missingIds = Set(missing.map(\.id))
        config.repos.removeAll { missingIds.contains($0.id) }
        try store.save(config)
        print(Style.paint("🗑️  Purged \(missing.count) repo\(missing.count == 1 ? "" : "s").", "32"))
        return 0
    }

    private func printList(store: any ConfigStore) throws -> Int32 {
        let config = try store.load() ?? Config()
        guard !config.repos.isEmpty else {
            print("📭 No repos configured. Add one with --add <path>.")
            return 0
        }
        print("📋 \(config.repos.count) repo\(config.repos.count == 1 ? "" : "s") tracked\n")
        for (index, entry) in config.repos.enumerated() {
            print(Style.paint("📦 \(entry.name)", "1;36") + "  " + Style.paint("(\(entry.id))", "2"))
            print("   📂 " + Style.paint(entry.repoPath, "2"))
            print("   💾 commit: \(entry.wipName)")
            print("   🔀 main: " + (entry.main ? Style.paint("true", "32") : Style.paint("false", "2")))
            if index < config.repos.count - 1 { print() }
        }
        return 0
    }

    // Standalone `--main <bool>`: retargets the repo the user is standing in.
    private func setMain(_ value: Bool, store: any ConfigStore) throws -> Int32 {
        var config = try store.load() ?? Config()
        let path = resolved(".")
        guard config.setMain(value, path: path) else {
            print(Style.paint("❌ \(path) is not in the config. Add it with --add.", "31"))
            return 1
        }
        try store.save(config)
        print(Style.paint("🔀 main set to \(value) for \(path)", "32"))
        return 0
    }

    private func setDefaultWipName(_ name: String, store: any ConfigStore) throws -> Int32 {
        var config = try store.load() ?? Config()
        config.defaultWipName = name
        try store.save(config)
        print(Style.paint("⚙️  Default commit prefix set to \"\(name)\"", "32"))
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
