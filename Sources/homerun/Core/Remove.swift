//
//  Remove.swift
//  homerun
//
//  Created by Jamie Le Souëf on 13/09/2026.
//

import Foundation

struct Remove {
    // Either a repo's id or its path ("." for the current folder).
    var target: String

    func run(store: any ConfigStore) throws -> Int32 {
        var config = try store.load() ?? Config()

        if let id = UUID(uuidString: target) {
            let removed = config.repos.first { $0.id == id }
            guard config.remove(id: id) else {
                print(Style.paint("❌ No repo with id \(target).", "31"))
                return 1
            }
            try store.save(config)
            print(Style.paint("🗑️  Removed \(removed?.repoPath ?? target)", "32") + "  " + Style.paint("(\(id))", "2"))
            return 0
        }

        let path = Paths.resolved(target)
        guard config.remove(path: path) else {
            print(Style.paint("❌ \(path) is not in the config.", "31"))
            return 1
        }
        try store.save(config)
        print(Style.paint("🗑️  Removed \(path)", "32"))
        return 0
    }
}
