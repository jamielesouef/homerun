//
//  ListRepos.swift
//  homerun
//
//  Created by Jamie Le Souëf on 13/09/2026.
//

struct ListRepos {
    func run(store: any ConfigStore) throws -> Int32 {
        let config = try store.load() ?? Config()
        guard !config.repos.isEmpty || !config.ignoredFolders.isEmpty else {
            print("📭 No repos configured. Add one with \"homerun add <path>\".")
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
}
