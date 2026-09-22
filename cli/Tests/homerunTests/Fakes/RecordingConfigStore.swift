//
//  RecordingConfigStore.swift
//  homerun
//
//  Created by Jamie Le Souëf on 08/09/2026.
//

@testable import homerun

// Records what would have been written, without touching disk.
final class RecordingConfigStore: ConfigStore, @unchecked Sendable {
    private var config: Config?
    private(set) var saved: Config?

    init(config: Config?) {
        self.config = config
    }

    func load() throws -> Config? { config }

    func save(_ config: Config) throws {
        saved = config
        self.config = config
    }
}
