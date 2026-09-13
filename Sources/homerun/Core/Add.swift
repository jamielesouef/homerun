//
//  Add.swift
//  homerun
//
//  Created by Jamie Le Souëf on 13/09/2026.
//

import Foundation

struct Add {
    var path: String
    var recursive: Bool
    var main: Bool?
    var wipName: String?

    func run(git: any GitClient, store: any ConfigStore) throws -> Int32 {
        let path = Paths.resolved(path)
        if path != self.path { print("📍 Resolved \"\(self.path)\" to \(path)") }
        var config = try store.load() ?? Config()

        if recursive {
            return try addRecursive(path, config: &config, git: git, store: store)
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

    private func addRecursive(_ path: String, config: inout Config, git: any GitClient, store: any ConfigStore) throws -> Int32 {
        let root = NSString(string: path).expandingTildeInPath
        let gitignored = RepoDiscovery.gitignoreEntries(atRoot: root)
        if !gitignored.isEmpty {
            print("🙈 Also skipping \(gitignored.count) entr\(gitignored.count == 1 ? "y" : "ies") from .gitignore")
        }
        print("🔎 Walking \(root) for git repos...")
        let found = RepoDiscovery.findRepos(in: root, git: git, ignoring: config.ignoredFolders + gitignored)
        if !found.isEmpty {
            print("📁 Found \(found.count) repo\(found.count == 1 ? "" : "s"):")
            for repoPath in found { print("   " + Style.paint(repoPath, "2")) }
            for repoPath in found {
                config.upsert(entry(for: repoPath, in: config))
            }
        }
        let missing = RepoDiscovery.missingEntries(in: config, git: git)
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

    // Re-adding a tracked repo keeps its `main` and `wipName` unless the flag was passed,
    // so `add --recursive` over a tree cannot quietly reset them.
    private func entry(for path: String, in config: Config) -> RepoEntry {
        let key = RepoEntry(repoPath: path, wipName: "", main: false).canonicalPath
        let existing = config.repos.first { $0.canonicalPath == key }
        return RepoEntry(
            repoPath: path,
            wipName: wipName ?? existing?.wipName ?? config.defaultWipName ?? "WIP",
            main: main ?? existing?.main ?? false)
    }
}
