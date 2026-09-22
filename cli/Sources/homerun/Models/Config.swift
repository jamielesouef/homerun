//
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
    // Folder names (e.g. "node_modules") or full paths skipped by --add --recursive.
    var ignoredFolders: [String] = []

    init(repos: [RepoEntry] = [], defaultWipName: String? = nil, ignoredFolders: [String] = []) {
        self.repos = repos
        self.defaultWipName = defaultWipName
        self.ignoredFolders = ignoredFolders
    }

    // A config written before ignoredFolders existed has no such key; default it on load.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        repos = try container.decodeIfPresent([RepoEntry].self, forKey: .repos) ?? []
        defaultWipName = try container.decodeIfPresent(String.self, forKey: .defaultWipName)
        ignoredFolders = try container.decodeIfPresent([String].self, forKey: .ignoredFolders) ?? []
    }

    mutating func upsert(_ entry: RepoEntry) {
        if let index = repos.firstIndex(where: { $0.canonicalPath == entry.canonicalPath }) {
            // Re-adding the same path updates it in place; its id does not churn.
            var updated = entry
            updated.id = repos[index].id
            repos[index] = updated
        } else {
            repos.append(entry)
        }
    }

    // Collapses entries that point at the same repo, keeping the first of each group
    // (so ids do not churn) and ORing `main` in, because dropping a `main: true`
    // would silently stop that repo being pushed. Returns the entries dropped.
    mutating func dedupe() -> [RepoEntry] {
        var kept: [RepoEntry] = []
        var indexByPath: [String: Int] = [:]
        var dropped: [RepoEntry] = []
        for entry in repos {
            if let index = indexByPath[entry.canonicalPath] {
                kept[index].main = kept[index].main || entry.main
                dropped.append(entry)
            } else {
                indexByPath[entry.canonicalPath] = kept.count
                kept.append(entry)
            }
        }
        repos = kept
        return dropped
    }

    // Every group with more than one entry, as (kept, dropped) pairs, for reporting.
    func duplicateGroups() -> [(kept: RepoEntry, dropped: [RepoEntry])] {
        var order: [String] = []
        var groups: [String: [RepoEntry]] = [:]
        for entry in repos {
            if groups[entry.canonicalPath] == nil { order.append(entry.canonicalPath) }
            groups[entry.canonicalPath, default: []].append(entry)
        }
        return order.compactMap { path in
            guard let group = groups[path], group.count > 1 else { return nil }
            return (kept: group[0], dropped: Array(group.dropFirst()))
        }
    }

    // Leaves the entry's id and every other field untouched.
    mutating func setMain(_ value: Bool, path: String) -> Bool {
        let key = RepoEntry(repoPath: path, wipName: "", main: false).canonicalPath
        guard let index = repos.firstIndex(where: { $0.canonicalPath == key }) else { return false }
        repos[index].main = value
        return true
    }

    // Returns false if `path` was already ignored, so the caller can report that.
    mutating func addIgnore(_ path: String) -> Bool {
        guard !ignoredFolders.contains(path) else { return false }
        ignoredFolders.append(path)
        return true
    }

    mutating func removeIgnore(_ path: String) -> Bool {
        let before = ignoredFolders.count
        ignoredFolders.removeAll { $0 == path }
        return ignoredFolders.count != before
    }

    mutating func remove(id: UUID) -> Bool {
        let before = repos.count
        repos.removeAll { $0.id == id }
        return repos.count != before
    }

    mutating func remove(path: String) -> Bool {
        let key = RepoEntry(repoPath: path, wipName: "", main: false).canonicalPath
        let before = repos.count
        repos.removeAll { $0.canonicalPath == key }
        return repos.count != before
    }
}
