//
//  Clean.swift
//  homerun
//
//  Created by Jamie Le Souëf on 13/09/2026.
//

struct Clean {
    var missing: Bool
    var dupes: Bool
    var all: Bool
    var yolo: Bool

    func run(git: any GitClient, store: any ConfigStore, confirmer: any Confirmer, stdinIsTTY: Bool) throws -> Int32 {
        if all { return try removeAll(store: store, confirmer: confirmer, stdinIsTTY: stdinIsTTY) }

        var config = try store.load() ?? Config()
        // Bare `clean` (neither flag passed) does both.
        let doMissing = missing || !dupes
        let doDupes = dupes || !missing

        let missingFound = doMissing ? RepoDiscovery.missingEntries(in: config, git: git) : []
        let dupGroups = doDupes ? config.duplicateGroups() : []

        if doMissing, !doDupes, missingFound.isEmpty {
            print("📭 No missing repos.")
            return 0
        }
        if doDupes, !doMissing, dupGroups.isEmpty {
            print("📭 No duplicate repos.")
            return 0
        }
        guard !missingFound.isEmpty || !dupGroups.isEmpty else {
            print("📭 Nothing to clean.")
            return 0
        }

        if !missingFound.isEmpty {
            print("👻 \(missingFound.count) repo\(missingFound.count == 1 ? "" : "s") no longer on disk:")
            for entry in missingFound { print("   " + Style.paint(entry.repoPath, "2")) }
        }
        if !dupGroups.isEmpty {
            print("👯 \(dupGroups.count) repo\(dupGroups.count == 1 ? "" : "s") tracked more than once:")
            for group in dupGroups {
                print("   " + Style.paint("keep ", "2") + group.kept.repoPath)
                for entry in group.dropped { print("   " + Style.paint("drop " + entry.repoPath, "2")) }
            }
        }

        let droppedCount = missingFound.count + dupGroups.reduce(0) { $0 + $1.dropped.count }
        if !yolo {
            guard stdinIsTTY else {
                print(Style.paint("❌ Not a TTY — pass --yes to run unattended.", "31"))
                return 1
            }
            guard confirmer.confirm(prompt: "🗑️  Remove \(droppedCount) entr\(droppedCount == 1 ? "y" : "ies")? [y/N] ") else {
                print("🙅 Cancelled. Nothing was changed.")
                return 0
            }
        }

        if !missingFound.isEmpty {
            let missingIds = Set(missingFound.map(\.id))
            config.repos.removeAll { missingIds.contains($0.id) }
        }
        if !dupGroups.isEmpty {
            _ = config.dedupe()
        }
        try store.save(config)
        if !missingFound.isEmpty {
            print(Style.paint("🗑️  Purged \(missingFound.count) repo\(missingFound.count == 1 ? "" : "s") no longer on disk.", "32"))
        }
        if !dupGroups.isEmpty {
            let droppedDupes = dupGroups.reduce(0) { $0 + $1.dropped.count }
            print(Style.paint("🗑️  Removed \(droppedDupes) duplicate entr\(droppedDupes == 1 ? "y" : "ies").", "32"))
        }
        return 0
    }

    private func removeAll(store: any ConfigStore, confirmer: any Confirmer, stdinIsTTY: Bool) throws -> Int32 {
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
}
