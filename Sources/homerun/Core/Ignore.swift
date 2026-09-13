//
//  Ignore.swift
//  homerun
//
//  Created by Jamie Le Souëf on 13/09/2026.
//

import Foundation

// The folders skipped during `add --recursive`.
enum Ignore {
    static func add(_ raws: [String], store: any ConfigStore) throws -> Int32 {
        var config = try store.load() ?? Config()
        var added: [String] = []
        var alreadyIgnored: [String] = []
        for raw in stripStrayCommas(raws) {
            let path = Paths.resolved(raw)
            if config.addIgnore(path) { added.append(path) } else { alreadyIgnored.append(path) }
        }
        if !added.isEmpty { try store.save(config) }
        for path in added { print(Style.paint("🙈 Ignoring \(path)", "32")) }
        for path in alreadyIgnored { print(Style.paint("❌ \(path) is already ignored.", "31")) }
        return alreadyIgnored.isEmpty ? 0 : 1
    }

    static func remove(_ raws: [String], store: any ConfigStore) throws -> Int32 {
        var config = try store.load() ?? Config()
        var removed: [String] = []
        var notIgnored: [String] = []
        for raw in stripStrayCommas(raws) {
            let path = Paths.resolved(raw)
            if config.removeIgnore(path) { removed.append(path) } else { notIgnored.append(path) }
        }
        if !removed.isEmpty { try store.save(config) }
        for path in removed { print(Style.paint("👁️  No longer ignoring \(path)", "32")) }
        for path in notIgnored { print(Style.paint("❌ \(path) is not ignored.", "31")) }
        return notIgnored.isEmpty ? 0 : 1
    }

    static func list(store: any ConfigStore) throws -> Int32 {
        let config = try store.load() ?? Config()
        guard !config.ignoredFolders.isEmpty else {
            print("📭 No folders ignored.")
            return 0
        }
        print("🙈 \(config.ignoredFolders.count) folder\(config.ignoredFolders.count == 1 ? "" : "s") ignored\n")
        for path in config.ignoredFolders { print("   " + Style.paint(path, "2")) }
        return 0
    }

    // A stray trailing comma (e.g. from `add .build, .git`) shouldn't end up baked into the config.
    private static func stripStrayCommas(_ raws: [String]) -> [String] {
        raws.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ",")) }
    }
}
