//  Config.swift
//  homerun
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

import Foundation

struct Config: Codable, Equatable, Sendable {
    var repos: [RepoEntry] = []
    // Falls back to "WIP" wherever this is nil; set via `--default-wip-name`.
    var defaultWipName: String?

    mutating func upsert(_ entry: RepoEntry) {
        if let index = repos.firstIndex(where: { $0.canonicalPath == entry.canonicalPath }) {
            repos[index] = entry
        } else {
            repos.append(entry)
        }
    }

    mutating func remove(path: String) -> Bool {
        let key = RepoEntry(repoPath: path, wipName: "", main: false).canonicalPath
        let before = repos.count
        repos.removeAll { $0.canonicalPath == key }
        return repos.count != before
    }
}
