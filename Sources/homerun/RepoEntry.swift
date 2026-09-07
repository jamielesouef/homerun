//  RepoEntry.swift
//  homerun
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

import Foundation

struct RepoEntry: Codable, Equatable, Sendable {
    var repoPath: String
    var wipName: String
    var main: Bool

    var expandedPath: String {
        NSString(string: repoPath).expandingTildeInPath
    }

    var name: String {
        URL(fileURLWithPath: expandedPath).lastPathComponent
    }

    // Duplicate detection compares this; the stored `repoPath` stays as typed.
    var canonicalPath: String {
        URL(fileURLWithPath: expandedPath).standardizedFileURL.path
    }
}
