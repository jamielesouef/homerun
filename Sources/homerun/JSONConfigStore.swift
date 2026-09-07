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
        return try JSONDecoder().decode(Config.self, from: data)
    }

    func save(_ config: Config) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(config).write(to: fileURL, options: .atomic)
    }
}
