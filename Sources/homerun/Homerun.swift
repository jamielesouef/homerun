//
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

    @Flag(name: [.customShort("s"), .customLong("wip"), .customLong("sync")], help: "Scan every tracked repo, show the plan, and push what needs it.")
    var wip = false

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

    @Flag(name: [.customShort("D"), .long], help: "Remove duplicate repos from the config, keeping one entry per repo.")
    var dedupe = false

    @Flag(name: [.customShort("R"), .long], help: "With --add: walk the directory tree, add every git repo found, purge any tracked repo whose path no longer exists, and drop any duplicate entries.")
    var recursive = false

    @Option(name: [.customShort("p"), .long], help: "Limit the scan to this configured repo. Repeatable.")
    var repo: [String] = []

    @Option(name: [.customShort("a"), .customLong("add"), .long], help: "Add a repo to the config and exit. \".\" means the current folder.")
    var addPath: String?

    @Option(name: [.customShort("r"), .customLong("remove"), .long], help: "Remove a repo from the config and exit, by its id, its path, or \".\" for the current folder.")
    var removePath: String?

    @Option(
        name: [.customShort("i"), .customLong("ignore")], parsing: .upToNextOption,
        help: "Manage the folders skipped during --add --recursive, and exit: \"add <name-or-path>\", \"remove <name-or-path>\", or \"list\". \".\" means the current folder.")
    var ignoreArgs: [String] = []

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
        if !ignoreArgs.isEmpty {
            guard let verb = ignoreArgs.first, ["add", "remove", "list"].contains(verb) else {
                throw ValidationError("--ignore needs \"add <name-or-path>...\", \"remove <name-or-path>...\", or \"list\".")
            }
            if verb == "list" {
                guard ignoreArgs.count == 1 else {
                    throw ValidationError("--ignore list takes no further arguments.")
                }
            } else {
                guard ignoreArgs.count >= 2 else {
                    throw ValidationError("--ignore \(verb) needs at least one name or path.")
                }
            }
        }
    }

    func run() async throws {
        let code = try perform(
            git: ProcessGitClient(),
            store: JSONConfigStore(),
            confirmer: ReadLineConfirmer(),
            auth: ProcessGitHubAuth(),
            stdinIsTTY: isatty(STDIN_FILENO) != 0,
            showProgress: isatty(STDOUT_FILENO) != 0
        )
        if code != 0 { throw ExitCode(code) }
    }

    // The whole decision flow, with every side-effecting dependency injected so tests can drive it.
    // `auth` defaults to nil and `showProgress` to false so existing tests need no change.
    func perform(
        git: any GitClient, store: any ConfigStore, confirmer: any Confirmer,
        auth: (any GitHubAuth)? = nil, stdinIsTTY: Bool, showProgress: Bool = false
    ) throws -> Int32 {
        if let defaultWipName { return try setDefaultWipName(defaultWipName, store: store) }
        if let addPath { return try add(addPath, git: git, store: store) }
        if let removePath { return try remove(removePath, store: store) }
        if !ignoreArgs.isEmpty { return try handleIgnore(ignoreArgs, store: store) }
        if let allowMain { return try setMain(allowMain, store: store) }
        if removeAll { return try removeAllRepos(store: store, confirmer: confirmer, stdinIsTTY: stdinIsTTY) }
        if purge { return try purgeMissing(git: git, store: store, confirmer: confirmer, stdinIsTTY: stdinIsTTY) }
        if dedupe { return try dedupeRepos(store: store, confirmer: confirmer, stdinIsTTY: stdinIsTTY) }
        if list { return try printList(store: store) }
        guard wip || dryRun else {
            print(Self.helpMessage())
            return 0
        }
        return try runSync(git: git, store: store, confirmer: confirmer, auth: auth, stdinIsTTY: stdinIsTTY, showProgress: showProgress)
    }

    private func runSync(
        git: any GitClient, store: any ConfigStore, confirmer: any Confirmer,
        auth: (any GitHubAuth)?, stdinIsTTY: Bool, showProgress: Bool
    ) throws -> Int32 {
        guard let config = try store.load(), !config.repos.isEmpty else {
            print("📭 No repos configured. Add one with --add <path>.")
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
            print(Style.paint("❌ \(path) is not in the config. Add it with --add.", "31"))
            return nil
        }
        return entries.filter { wanted.contains($0.canonicalPath) }
    }

    // Re-adding a tracked repo keeps its `main` and `wipName` unless the flag was passed,
    // so `--add --recursive` over a tree cannot quietly reset them.
    private func entry(for path: String, in config: Config) -> RepoEntry {
        let key = RepoEntry(repoPath: path, wipName: "", main: false).canonicalPath
        let existing = config.repos.first { $0.canonicalPath == key }
        return RepoEntry(
            repoPath: path,
            wipName: wipName ?? existing?.wipName ?? config.defaultWipName ?? "WIP",
            main: allowMain ?? existing?.main ?? false)
    }

    private func add(_ rawPath: String, git: any GitClient, store: any ConfigStore) throws -> Int32 {
        let path = resolved(rawPath)
        if path != rawPath { print("📍 Resolved \"\(rawPath)\" to \(path)") }
        var config = try store.load() ?? Config()

        if recursive {
            let root = NSString(string: path).expandingTildeInPath
            let gitignored = Self.gitignoreEntries(atRoot: root)
            if !gitignored.isEmpty {
                print("🙈 Also skipping \(gitignored.count) entr\(gitignored.count == 1 ? "y" : "ies") from .gitignore")
            }
            print("🔎 Walking \(root) for git repos...")
            let found = Self.findRepos(in: root, git: git, ignoring: config.ignoredFolders + gitignored)
            if !found.isEmpty {
                print("📁 Found \(found.count) repo\(found.count == 1 ? "" : "s"):")
                for repoPath in found { print("   " + Style.paint(repoPath, "2")) }
                for repoPath in found {
                    config.upsert(entry(for: repoPath, in: config))
                }
            }
            let missing = missingEntries(in: config, git: git)
            if !missing.isEmpty {
                let missingIds = Set(missing.map(\.id))
                config.repos.removeAll { missingIds.contains($0.id) }
            }
            let duplicates = config.dedupe()
            guard !found.isEmpty || !missing.isEmpty || !duplicates.isEmpty else {
                print(Style.paint("❌ No git repos found under \(path).", "31"))
                return 1
            }
            try store.save(config)
            if !found.isEmpty {
                print(Style.paint("✅ Added \(found.count) repo\(found.count == 1 ? "" : "s") under \(path)", "32"))
            }
            if !missing.isEmpty {
                print(Style.paint("🗑️  Purged \(missing.count) repo\(missing.count == 1 ? "" : "s") no longer on disk.", "32"))
            }
            if !duplicates.isEmpty {
                print(Style.paint("👯 Dropped \(duplicates.count) duplicate entr\(duplicates.count == 1 ? "y" : "ies").", "32"))
            }
            return 0
        }

        print("🔍 Checking \(path) is a git repo...")
        let entry = entry(for: path, in: config)
        guard git.isRepo(at: entry.expandedPath) else {
            print(Style.paint("❌ \(path) is not a git repo.", "31"))
            return 1
        }
        let alreadyTracked = config.repos.contains { $0.canonicalPath == entry.canonicalPath }
        config.upsert(entry)
        try store.save(config)
        let id = config.repos.first(where: { $0.canonicalPath == entry.canonicalPath })?.id ?? entry.id
        let headline = alreadyTracked ? "🔁 Already tracked, updated \(path)" : "✅ Added \(path)"
        print(Style.paint(headline, "32") + "  " + Style.paint("(\(id))", "2"))
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

    private func handleIgnore(_ args: [String], store: any ConfigStore) throws -> Int32 {
        // A stray trailing comma (e.g. from `add .build, .git`) shouldn't end up baked into the config.
        let items = args.dropFirst().map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ",")) }
        switch args[0] {
        case "add": return try addIgnore(items, store: store)
        case "remove": return try removeIgnore(items, store: store)
        default: return try listIgnored(store: store)
        }
    }

    private func addIgnore(_ raws: [String], store: any ConfigStore) throws -> Int32 {
        var config = try store.load() ?? Config()
        var added: [String] = []
        var alreadyIgnored: [String] = []
        for raw in raws {
            let path = resolved(raw)
            if config.addIgnore(path) { added.append(path) } else { alreadyIgnored.append(path) }
        }
        if !added.isEmpty { try store.save(config) }
        for path in added { print(Style.paint("🙈 Ignoring \(path)", "32")) }
        for path in alreadyIgnored { print(Style.paint("❌ \(path) is already ignored.", "31")) }
        return alreadyIgnored.isEmpty ? 0 : 1
    }

    private func removeIgnore(_ raws: [String], store: any ConfigStore) throws -> Int32 {
        var config = try store.load() ?? Config()
        var removed: [String] = []
        var notIgnored: [String] = []
        for raw in raws {
            let path = resolved(raw)
            if config.removeIgnore(path) { removed.append(path) } else { notIgnored.append(path) }
        }
        if !removed.isEmpty { try store.save(config) }
        for path in removed { print(Style.paint("👁️  No longer ignoring \(path)", "32")) }
        for path in notIgnored { print(Style.paint("❌ \(path) is not ignored.", "31")) }
        return notIgnored.isEmpty ? 0 : 1
    }

    private func listIgnored(store: any ConfigStore) throws -> Int32 {
        let config = try store.load() ?? Config()
        guard !config.ignoredFolders.isEmpty else {
            print("📭 No folders ignored.")
            return 0
        }
        print("🙈 \(config.ignoredFolders.count) folder\(config.ignoredFolders.count == 1 ? "" : "s") ignored\n")
        for path in config.ignoredFolders { print("   " + Style.paint(path, "2")) }
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

    private func missingEntries(in config: Config, git: any GitClient) -> [RepoEntry] {
        config.repos.filter { !git.isRepo(at: $0.expandedPath) }
    }

    private func purgeMissing(git: any GitClient, store: any ConfigStore, confirmer: any Confirmer, stdinIsTTY: Bool) throws -> Int32 {
        var config = try store.load() ?? Config()
        let missing = missingEntries(in: config, git: git)
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

    private func dedupeRepos(store: any ConfigStore, confirmer: any Confirmer, stdinIsTTY: Bool) throws -> Int32 {
        var config = try store.load() ?? Config()
        let groups = config.duplicateGroups()
        guard !groups.isEmpty else {
            print("📭 No duplicate repos.")
            return 0
        }
        let count = groups.reduce(0) { $0 + $1.dropped.count }
        print("👯 \(groups.count) repo\(groups.count == 1 ? "" : "s") tracked more than once:")
        for group in groups {
            print("   " + Style.paint("keep ", "2") + group.kept.repoPath)
            for entry in group.dropped { print("   " + Style.paint("drop " + entry.repoPath, "2")) }
        }
        if !yolo {
            guard stdinIsTTY else {
                print(Style.paint("❌ Not a TTY — pass --yes to run unattended.", "31"))
                return 1
            }
            guard confirmer.confirm(prompt: "🗑️  Remove \(count) duplicate entr\(count == 1 ? "y" : "ies")? [y/N] ") else {
                print("🙅 Cancelled. Nothing was changed.")
                return 0
            }
        }
        _ = config.dedupe()
        try store.save(config)
        print(Style.paint("🗑️  Removed \(count) duplicate entr\(count == 1 ? "y" : "ies").", "32"))
        return 0
    }

    private func printList(store: any ConfigStore) throws -> Int32 {
        let config = try store.load() ?? Config()
        guard !config.repos.isEmpty || !config.ignoredFolders.isEmpty else {
            print("📭 No repos configured. Add one with --add <path>.")
            return 0
        }
        if !config.repos.isEmpty {
            print("📋 \(config.repos.count) repo\(config.repos.count == 1 ? "" : "s") tracked\n")
            for (index, entry) in config.repos.enumerated() {
                print(Style.paint("📦 \(entry.name)", "1;36") + "  " + Style.paint("(\(entry.id))", "2"))
                print("   📂 " + Style.paint(entry.repoPath, "2"))
                print("   💾 commit: \(entry.wipName)")
                print("   🔀 main: " + (entry.main ? Style.paint("true", "32") : Style.paint("false", "2")))
                if index < config.repos.count - 1 { print() }
            }
        }
        if !config.ignoredFolders.isEmpty {
            if !config.repos.isEmpty { print() }
            print("🙈 \(config.ignoredFolders.count) folder\(config.ignoredFolders.count == 1 ? "" : "s") ignored\n")
            for path in config.ignoredFolders { print("   " + Style.paint(path, "2")) }
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

    // Reads a top-level .gitignore at the walked root (if any) as extra, one-off ignore entries —
    // never saved to config. Only plain name/path entries are honoured, same as --ignore itself:
    // comments, blank lines, negation ("!"), and wildcards ("*") are skipped, not translated.
    private static func gitignoreEntries(atRoot root: String) -> [String] {
        guard let contents = try? String(contentsOfFile: root + "/.gitignore", encoding: .utf8) else { return [] }
        return contents.split(separator: "\n").compactMap { rawLine -> String? in
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#"), !line.hasPrefix("!"), !line.contains("*") else { return nil }
            if line.hasSuffix("/") { line.removeLast() }
            if line.hasPrefix("/") { line.removeFirst() }
            return line.contains("/") ? root + "/" + line : line
        }
    }

    // Descends until it finds a repo, then stops — nested/submodule repos below it are not walked.
    // Follows symlinked directories, but a canonical-path visited set breaks any symlink cycle.
    private static func findRepos(in root: String, git: any GitClient, ignoring: [String]) -> [String] {
        var visited: Set<String> = []
        return findRepos(in: root, git: git, ignoring: ignoring, visited: &visited)
    }

    private static func findRepos(in root: String, git: any GitClient, ignoring: [String], visited: inout Set<String>) -> [String] {
        let canonical = URL(fileURLWithPath: root).resolvingSymlinksInPath().path
        guard visited.insert(canonical).inserted else { return [] }
        guard !isIgnored(root, ignoring: ignoring) else { return [] }
        if git.isRepo(at: root) { return [root] }
        guard let children = try? FileManager.default.contentsOfDirectory(atPath: root) else { return [] }
        var found: [String] = []
        for child in children where child != ".git" {
            let path = root + "/" + child
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else { continue }
            found += findRepos(in: path, git: git, ignoring: ignoring, visited: &visited)
        }
        return found
    }

    // An ignore entry with a "/" is matched as a full path (symlinks resolved);
    // a bare name (e.g. "node_modules") is matched against every folder with that name.
    private static func isIgnored(_ path: String, ignoring: [String]) -> Bool {
        guard !ignoring.isEmpty else { return false }
        let name = URL(fileURLWithPath: path).lastPathComponent
        let canonical = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
        return ignoring.contains { entry in
            guard entry.contains("/") else { return entry == name }
            let entryPath = NSString(string: entry).expandingTildeInPath
            return URL(fileURLWithPath: entryPath).standardizedFileURL.resolvingSymlinksInPath().path == canonical
        }
    }
}
