//  JSONConfigStore.swift
//  homerun
//
//  Created by Jamie Le Souëf on 08/09/2026.
//

import Foundation

struct JSONConfigStore: ConfigStore {
    var fileURL: URL

    init(fileURL: URL? = nil) {
        // Honour $HOME like other CLIs do; `homeDirectoryForCurrentUser` ignores it.
        let home = ProcessInfo.processInfo.environment["HOME"].map(URL.init(fileURLWithPath:))
            ?? FileManager.default.homeDirectoryForCurrentUser
        self.fileURL = fileURL ?? home.appendingPathComponent(".config/homerun/config.json")
    }

    func load() throws -> Config? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        let config = try JSONDecoder().decode(Config.self, from: data)
        // A pre-id config mints a fresh UUID per entry on decode; write it back once
        // so `--list` and a later `--remove <id>` see the same id across runs.
        if try hasEntryMissingId(in: data) {
            try save(config)
        }
        return config
    }

    private struct IdProbe: Decodable {
        struct Entry: Decodable { var id: UUID? }
        var repos: [Entry]
    }

    private func hasEntryMissingId(in data: Data) throws -> Bool {
        try JSONDecoder().decode(IdProbe.self, from: data).repos.contains { $0.id == nil }
    }

    func save(_ config: Config) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(config).write(to: fileURL, options: .atomic)
    }
}
