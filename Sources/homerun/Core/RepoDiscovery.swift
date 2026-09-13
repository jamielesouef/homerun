//
//  RepoDiscovery.swift
//  homerun
//
//  Created by Jamie Le Souëf on 13/09/2026.
//

import Foundation

// Filesystem-walking helpers shared by `add --recursive` and `clean --missing`.
enum RepoDiscovery {
    static func missingEntries(in config: Config, git: any GitClient) -> [RepoEntry] {
        config.repos.filter { !git.isRepo(at: $0.expandedPath) }
    }

    // Reads a top-level .gitignore at the walked root (if any) as extra, one-off ignore entries —
    // never saved to config. Only plain name/path entries are honoured, same as `ignore` itself:
    // comments, blank lines, negation ("!"), and wildcards ("*") are skipped, not translated.
    static func gitignoreEntries(atRoot root: String) -> [String] {
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
    static func findRepos(in root: String, git: any GitClient, ignoring: [String]) -> [String] {
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
