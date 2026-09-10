//
//  ConfigStore.swift
//  homerun
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

protocol ConfigStore: Sendable {
    // nil means no config file exists yet.
    func load() throws -> Config?
    func save(_ config: Config) throws
}
