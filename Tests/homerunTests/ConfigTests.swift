//  ConfigTests.swift
//  homerun
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

import Foundation
import Testing
@testable import homerun

struct ConfigTests {
    let store = JSONConfigStore(
        fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("homerun-tests-\(UUID().uuidString)/config.json"))

    @Test func missingFileLoadsAsNil() throws {
        #expect(try store.load() == nil)
    }

    @Test func addThenRemoveRoundTripsAndKeepsOthers() throws {
        let keep = RepoEntry(repoPath: "~/dev/keep", wipName: "WIP", main: true)
        let temp = RepoEntry(repoPath: "~/dev/temp", wipName: "Save", main: false)
        var config = Config()
        config.upsert(keep)
        config.upsert(temp)
        try store.save(config)
        #expect(try store.load() == config)

        var loaded = try #require(try store.load())
        let removed = loaded.remove(path: "~/dev/temp")
        let removedAgain = loaded.remove(path: "~/dev/temp")
        #expect(removed)
        #expect(!removedAgain)
        try store.save(loaded)
        #expect(try store.load()?.repos == [keep])
    }

    @Test func defaultWipNameRoundTripsAndOmitsWhenNil() throws {
        var config = Config()
        config.defaultWipName = "SAVE"
        try store.save(config)
        #expect(try store.load()?.defaultWipName == "SAVE")

        try store.save(Config())
        #expect(try store.load()?.defaultWipName == nil)
    }

    @Test func duplicatePathUpdatesInPlace() {
        var config = Config(repos: [RepoEntry(repoPath: "~/dev/foo", wipName: "WIP", main: false)])
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        config.upsert(RepoEntry(repoPath: "\(home)/dev/foo", wipName: "Changed", main: true))
        #expect(config.repos.count == 1)
        #expect(config.repos[0].wipName == "Changed")
        #expect(config.repos[0].main)
    }
}
