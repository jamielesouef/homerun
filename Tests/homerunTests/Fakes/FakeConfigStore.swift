//  FakeConfigStore.swift
//  homerun
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

@testable import homerun

struct FakeConfigStore: ConfigStore {
    var config: Config?

    func load() throws -> Config? { config }

    func save(_ config: Config) throws {}
}
