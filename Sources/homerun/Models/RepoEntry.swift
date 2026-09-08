//  RepoEntry.swift
//  homerun
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

import Foundation

struct RepoEntry: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var repoPath: String
    var wipName: String
    var main: Bool

    init(id: UUID = UUID(), repoPath: String, wipName: String, main: Bool) {
        self.id = id
        self.repoPath = repoPath
        self.wipName = wipName
        self.main = main
    }

    // A config written before ids existed has no "id" key; give it one on load.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        repoPath = try container.decode(String.self, forKey: .repoPath)
        wipName = try container.decode(String.self, forKey: .wipName)
        main = try container.decode(Bool.self, forKey: .main)
    }

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
