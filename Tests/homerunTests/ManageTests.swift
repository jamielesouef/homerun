//  ManageTests.swift
//  homerun
//
//  Created by Jamie Le Souëf on 08/09/2026.
//

import Foundation
import Testing
@testable import homerun

// Covers the config-mutation flags: --add/--remove (with "."), --remove-all,
// --list, --default-wip-name, and --recursive. All against a fake GitClient and
// a fake ConfigStore — no test touches the real config file or a real repo.
struct ManageTests {
    func perform(
        _ arguments: [String], config: Config, git: FakeGitClient = FakeGitClient([:]),
        confirm: Bool = true, tty: Bool = false
    ) throws -> (code: Int32, store: RecordingConfigStore) {
        let store = RecordingConfigStore(config: config)
        let code = try Homerun.parse(arguments).perform(
            git: git, store: store, confirmer: FakeConfirmer(answer: confirm), stdinIsTTY: tty)
        return (code, store)
    }

    @Test func dotResolvesToCurrentDirectoryOnAdd() throws {
        let cwd = FileManager.default.currentDirectoryPath
        let git = FakeGitClient([cwd: .init()])
        let (code, store) = try perform(["--add", "."], config: Config(), git: git)
        #expect(code == 0)
        #expect(store.saved?.repos.first?.repoPath == cwd)
    }

    @Test func dotResolvesToCurrentDirectoryOnRemove() throws {
        let cwd = FileManager.default.currentDirectoryPath
        let existing = Config(repos: [RepoEntry(repoPath: cwd, wipName: "WIP", main: false)])
        let (code, store) = try perform(["--remove", "."], config: existing)
        #expect(code == 0)
        #expect(store.saved?.repos.isEmpty == true)
    }

    @Test func mainFlagAloneUpdatesTheRepoInTheCurrentFolder() throws {
        let cwd = FileManager.default.currentDirectoryPath
        let existing = Config(repos: [RepoEntry(repoPath: cwd, wipName: "WIP", main: false)])
        let (code, store) = try perform(["--main", "true"], config: existing)
        #expect(code == 0)
        #expect(store.saved?.repos.first?.main == true)
        #expect(store.saved?.repos.first?.id == existing.repos[0].id)
    }

    @Test func mainFlagAloneFailsOutsideAConfiguredRepo() throws {
        let existing = Config(repos: [RepoEntry(repoPath: "/somewhere/else", wipName: "WIP", main: false)])
        let (code, store) = try perform(["--main", "false"], config: existing)
        #expect(code == 1)
        #expect(store.saved == nil)
    }

    @Test func mainFlagStillAppliesToTheRepoBeingAdded() throws {
        let cwd = FileManager.default.currentDirectoryPath
        let git = FakeGitClient([cwd: .init()])
        let (code, store) = try perform(["--add", ".", "--main", "true"], config: Config(), git: git)
        #expect(code == 0)
        #expect(store.saved?.repos.first?.main == true)
    }

    @Test func removeAllClearsEveryRepoWithYolo() throws {
        let existing = Config(repos: [
            RepoEntry(repoPath: "/a", wipName: "WIP", main: false),
            RepoEntry(repoPath: "/b", wipName: "WIP", main: false),
        ])
        let (code, store) = try perform(["--remove-all", "--yolo"], config: existing)
        #expect(code == 0)
        #expect(store.saved?.repos.isEmpty == true)
    }

    @Test func removeAllAsksAndProceedsOnYes() throws {
        let existing = Config(repos: [RepoEntry(repoPath: "/a", wipName: "WIP", main: false)])
        let (code, store) = try perform(["--remove-all"], config: existing, confirm: true, tty: true)
        #expect(code == 0)
        #expect(store.saved?.repos.isEmpty == true)
    }

    @Test func removeAllDeclinedWritesNothing() throws {
        let existing = Config(repos: [RepoEntry(repoPath: "/a", wipName: "WIP", main: false)])
        let (code, store) = try perform(["--remove-all"], config: existing, confirm: false, tty: true)
        #expect(code == 0)
        #expect(store.saved == nil)
    }

    @Test func removeAllNonTTYWithoutYoloIsAnError() throws {
        let existing = Config(repos: [RepoEntry(repoPath: "/a", wipName: "WIP", main: false)])
        let (code, store) = try perform(["--remove-all"], config: existing, tty: false)
        #expect(code == 1)
        #expect(store.saved == nil)
    }

    @Test func removeByUUID() throws {
        let entry = RepoEntry(repoPath: "/a", wipName: "WIP", main: false)
        let existing = Config(repos: [entry, RepoEntry(repoPath: "/b", wipName: "WIP", main: false)])
        let (code, store) = try perform(["--remove", entry.id.uuidString], config: existing)
        #expect(code == 0)
        #expect(store.saved?.repos.map(\.repoPath) == ["/b"])
    }

    @Test func removeByUnknownUUIDFails() throws {
        let existing = Config(repos: [RepoEntry(repoPath: "/a", wipName: "WIP", main: false)])
        let (code, store) = try perform(["--remove", UUID().uuidString], config: existing)
        #expect(code == 1)
        #expect(store.saved == nil)
    }

    @Test func idStaysStableAcrossReAdd() throws {
        let git = FakeGitClient(["/a": .init()])
        let (code1, store1) = try perform(["--add", "/a"], config: Config(), git: git)
        #expect(code1 == 0)
        let firstId = store1.saved?.repos.first?.id

        let (code2, store2) = try perform(["--add", "/a", "--wip-name", "SNAP"], config: store1.saved!, git: git)
        #expect(code2 == 0)
        #expect(store2.saved?.repos.first?.id == firstId)
    }

    @Test func listPrintsWithoutWriting() throws {
        let existing = Config(repos: [RepoEntry(repoPath: "/a", wipName: "WIP", main: false)])
        let (code, store) = try perform(["--list"], config: existing)
        #expect(code == 0)
        #expect(store.saved == nil)
    }

    @Test func defaultWipNameIsUsedWhenAddOmitsItsOwn() throws {
        let git = FakeGitClient(["/a": .init()])
        let (code, store) = try perform(["--add", "/a"], config: Config(defaultWipName: "SAVE"), git: git)
        #expect(code == 0)
        #expect(store.saved?.repos.first?.wipName == "SAVE")
    }

    @Test func explicitWipNameOverridesDefault() throws {
        let git = FakeGitClient(["/a": .init()])
        let (code, store) = try perform(["--add", "/a", "--wip-name", "SNAP"], config: Config(defaultWipName: "SAVE"), git: git)
        #expect(code == 0)
        #expect(store.saved?.repos.first?.wipName == "SNAP")
    }

    @Test func settingDefaultWipNameStoresItAndDoesNotScan() throws {
        let (code, store) = try perform(["--default-wip-name", "SAVE"], config: Config())
        #expect(code == 0)
        #expect(store.saved?.defaultWipName == "SAVE")
    }

    @Test func recursiveAddFindsEveryRepoUnderRoot() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("homerun-recursive-\(UUID().uuidString)")
        let repoA = root.appendingPathComponent("a")
        let repoB = root.appendingPathComponent("nested/b")
        let plain = root.appendingPathComponent("just-a-folder")
        try FileManager.default.createDirectory(at: repoA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: repoB, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: plain, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        // FakeGitClient decides what counts as a repo; no real `.git` needed.
        let git = FakeGitClient([repoA.path: .init(), repoB.path: .init()])
        let (code, store) = try perform(["--add", root.path, "--recursive"], config: Config(), git: git)
        #expect(code == 0)
        #expect(Set(store.saved?.repos.map(\.repoPath) ?? []) == [repoA.path, repoB.path])
    }

    @Test func recursiveWithoutAddIsRejected() {
        #expect(throws: (any Error).self) { try Homerun.parse(["--recursive"]) }
    }

    @Test func purgeRemovesOnlyMissingReposWithYolo() throws {
        let git = FakeGitClient(["/a": .init()])
        let existing = Config(repos: [
            RepoEntry(repoPath: "/a", wipName: "WIP", main: false),
            RepoEntry(repoPath: "/gone", wipName: "WIP", main: false),
        ])
        let (code, store) = try perform(["--purge", "--yolo"], config: existing, git: git)
        #expect(code == 0)
        #expect(store.saved?.repos.map(\.repoPath) == ["/a"])
    }

    @Test func purgeWithNothingMissingWritesNothing() throws {
        let git = FakeGitClient(["/a": .init()])
        let existing = Config(repos: [RepoEntry(repoPath: "/a", wipName: "WIP", main: false)])
        let (code, store) = try perform(["--purge", "--yolo"], config: existing, git: git)
        #expect(code == 0)
        #expect(store.saved == nil)
    }

    @Test func purgeDeclinedWritesNothing() throws {
        let existing = Config(repos: [RepoEntry(repoPath: "/gone", wipName: "WIP", main: false)])
        let (code, store) = try perform(["--purge"], config: existing, confirm: false, tty: true)
        #expect(code == 0)
        #expect(store.saved == nil)
    }

    @Test func purgeNonTTYWithoutYoloIsAnError() throws {
        let existing = Config(repos: [RepoEntry(repoPath: "/gone", wipName: "WIP", main: false)])
        let (code, store) = try perform(["--purge"], config: existing, tty: false)
        #expect(code == 1)
        #expect(store.saved == nil)
    }
}
