//
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

    @Test func duplicatePathUpdatesInPlaceAndKeepsSameId() {
        let original = RepoEntry(repoPath: "~/dev/foo", wipName: "WIP", main: false)
        var config = Config(repos: [original])
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        config.upsert(RepoEntry(repoPath: "\(home)/dev/foo", wipName: "Changed", main: true))
        #expect(config.repos.count == 1)
        #expect(config.repos[0].wipName == "Changed")
        #expect(config.repos[0].main)
        #expect(config.repos[0].id == original.id)
    }

    @Test func legacyConfigWithoutIdsStillLoads() throws {
        let legacyJSON = Data("""
        {"repos":[{"repoPath":"~/dev/old","wipName":"WIP","main":false}]}
        """.utf8)
        try FileManager.default.createDirectory(at: store.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try legacyJSON.write(to: store.fileURL)
        let loaded = try #require(try store.load())
        #expect(loaded.repos.first?.repoPath == "~/dev/old")

        // The minted id must be written back, or every load hands out a new one.
        let again = try #require(try store.load())
        #expect(again.repos.first?.id == loaded.repos.first?.id)
    }

    // The bug that filled the config with duplicates: ~/Developer was a symlink to
    // /Volumes/S990/Developer, so the same repo was tracked under both spellings.
    @Test func canonicalPathSeesThroughASymlink() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("homerun-symlink-\(UUID().uuidString)")
        let real = root.appendingPathComponent("real")
        let link = root.appendingPathComponent("link")
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
        defer { try? FileManager.default.removeItem(at: root) }

        let viaReal = RepoEntry(repoPath: real.path, wipName: "WIP", main: false)
        let viaLink = RepoEntry(repoPath: link.path, wipName: "WIP", main: false)
        #expect(viaReal.canonicalPath == viaLink.canonicalPath)

        var config = Config(repos: [viaReal])
        config.upsert(viaLink)
        #expect(config.repos.count == 1)
        #expect(config.repos.first?.id == viaReal.id)
    }

    @Test func dedupeReturnsTheEntriesItDropped() {
        var config = Config(repos: [
            RepoEntry(repoPath: "/tmp", wipName: "WIP", main: false),
            RepoEntry(repoPath: "/private/tmp", wipName: "WIP", main: false),
            RepoEntry(repoPath: "/b", wipName: "WIP", main: false),
        ])
        let dropped = config.dedupe()
        #expect(dropped.map(\.repoPath) == ["/private/tmp"])
        #expect(config.repos.map(\.repoPath) == ["/tmp", "/b"])
        #expect(config.dedupe().isEmpty)
    }
}
