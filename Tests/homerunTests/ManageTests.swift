//
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

    @Test func recursiveAddStopsAtARepoAndTracksItInsteadOfWalkingInside() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("homerun-recursive-\(UUID().uuidString)")
        let repo = root.appendingPathComponent("repo")
        let nestedInsideRepo = repo.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: nestedInsideRepo, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        // Both `repo` and the folder nested inside it look like repos to the fake client;
        // once `repo` is found the walk must not descend into `sub` at all.
        let git = FakeGitClient([repo.path: .init(), nestedInsideRepo.path: .init()])
        let (code, store) = try perform(["--add", root.path, "--recursive"], config: Config(), git: git)
        #expect(code == 0)
        #expect(store.saved?.repos.map(\.repoPath) == [repo.path])
    }

    @Test func recursiveWithoutAddIsRejected() {
        #expect(throws: (any Error).self) { try Homerun.parse(["--recursive"]) }
    }

    // A symlink pointing back at an ancestor once hung the walk forever; the
    // canonical-path visited set must break the cycle and still return the repo.
    @Test func recursiveAddTerminatesOnASymlinkCycle() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("homerun-cycle-\(UUID().uuidString)")
        let repoA = root.appendingPathComponent("a")
        let loop = root.appendingPathComponent("loop")
        try FileManager.default.createDirectory(at: repoA, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: loop, withDestinationURL: root)
        defer { try? FileManager.default.removeItem(at: root) }

        let git = FakeGitClient([repoA.path: .init()])
        let (code, store) = try perform(["--add", root.path, "--recursive"], config: Config(), git: git)
        #expect(code == 0)
        #expect(store.saved?.repos.map(\.repoPath) == [repoA.path])
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

    @Test func recursiveAddAlsoPurgesMissingTrackedRepos() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("homerun-recursive-\(UUID().uuidString)")
        let repoA = root.appendingPathComponent("a")
        try FileManager.default.createDirectory(at: repoA, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let git = FakeGitClient([repoA.path: .init()])
        let existing = Config(repos: [RepoEntry(repoPath: "/gone", wipName: "WIP", main: false)])
        let (code, store) = try perform(["--add", root.path, "--recursive"], config: existing, git: git)
        #expect(code == 0)
        #expect(store.saved?.repos.map(\.repoPath) == [repoA.path])
    }

    @Test func recursiveAddPurgesEvenWithNothingNewFound() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("homerun-recursive-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let git = FakeGitClient([:])
        let existing = Config(repos: [RepoEntry(repoPath: "/gone", wipName: "WIP", main: false)])
        let (code, store) = try perform(["--add", root.path, "--recursive"], config: existing, git: git)
        #expect(code == 0)
        #expect(store.saved?.repos.isEmpty == true)
    }

    // `/private/tmp` is the real directory `/tmp` symlinks to, so both spellings
    // canonicalise to the same repo — the same shape as ~/Developer symlinked to
    // an external volume, which is what put duplicates in the config.
    @Test func dedupeCollapsesSymlinkedDuplicatesWithYolo() throws {
        let existing = Config(repos: [
            RepoEntry(repoPath: "/tmp", wipName: "WIP", main: false),
            RepoEntry(repoPath: "/private/tmp", wipName: "WIP", main: false),
            RepoEntry(repoPath: "/b", wipName: "WIP", main: false),
        ])
        let (code, store) = try perform(["--dedupe", "--yolo"], config: existing)
        #expect(code == 0)
        #expect(store.saved?.repos.map(\.repoPath) == ["/tmp", "/b"])
    }

    @Test func dedupeKeepsTheFirstIdAndOrsMainIn() throws {
        let first = RepoEntry(repoPath: "/tmp", wipName: "WIP", main: false)
        let existing = Config(repos: [
            first,
            RepoEntry(repoPath: "/private/tmp", wipName: "Save", main: true),
        ])
        let (code, store) = try perform(["--dedupe", "--yolo"], config: existing)
        #expect(code == 0)
        #expect(store.saved?.repos.count == 1)
        #expect(store.saved?.repos.first?.id == first.id)
        #expect(store.saved?.repos.first?.wipName == "WIP")
        #expect(store.saved?.repos.first?.main == true)
    }

    @Test func dedupeWithNoDuplicatesWritesNothing() throws {
        let existing = Config(repos: [
            RepoEntry(repoPath: "/a", wipName: "WIP", main: false),
            RepoEntry(repoPath: "/b", wipName: "WIP", main: false),
        ])
        let (code, store) = try perform(["--dedupe", "--yolo"], config: existing)
        #expect(code == 0)
        #expect(store.saved == nil)
    }

    @Test func dedupeDeclinedWritesNothing() throws {
        let existing = Config(repos: [
            RepoEntry(repoPath: "/tmp", wipName: "WIP", main: false),
            RepoEntry(repoPath: "/private/tmp", wipName: "WIP", main: false),
        ])
        let (code, store) = try perform(["--dedupe"], config: existing, confirm: false, tty: true)
        #expect(code == 0)
        #expect(store.saved == nil)
    }

    @Test func dedupeNonTTYWithoutYoloIsAnError() throws {
        let existing = Config(repos: [
            RepoEntry(repoPath: "/tmp", wipName: "WIP", main: false),
            RepoEntry(repoPath: "/private/tmp", wipName: "WIP", main: false),
        ])
        let (code, store) = try perform(["--dedupe"], config: existing, tty: false)
        #expect(code == 1)
        #expect(store.saved == nil)
    }

    @Test func addDoesNotDuplicateARepoAlreadyTrackedByItsSymlinkedPath() throws {
        let git = FakeGitClient(["/private/tmp": .init(), "/tmp": .init()])
        let existing = Config(repos: [RepoEntry(repoPath: "/tmp", wipName: "WIP", main: false)])
        let (code, store) = try perform(["--add", "/private/tmp"], config: existing, git: git)
        #expect(code == 0)
        #expect(store.saved?.repos.count == 1)
    }

    @Test func recursiveAddDropsDuplicatesAlreadyInTheConfig() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("homerun-dedupe-\(UUID().uuidString)")
        let repoA = root.appendingPathComponent("a")
        try FileManager.default.createDirectory(at: repoA, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let git = FakeGitClient([repoA.path: .init(), "/tmp": .init(), "/private/tmp": .init()])
        let existing = Config(repos: [
            RepoEntry(repoPath: "/tmp", wipName: "WIP", main: false),
            RepoEntry(repoPath: "/private/tmp", wipName: "WIP", main: false),
        ])
        let (code, store) = try perform(["--add", root.path, "--recursive"], config: existing, git: git)
        #expect(code == 0)
        #expect(store.saved?.repos.map(\.repoPath) == ["/tmp", repoA.path])
    }

    @Test func reAddKeepsMainAndWipNameWhenNoFlagIsPassed() throws {
        let git = FakeGitClient(["/tmp": .init(), "/private/tmp": .init()])
        let existing = Config(repos: [RepoEntry(repoPath: "/tmp", wipName: "Save", main: true)])
        let (code, store) = try perform(["--add", "/private/tmp"], config: existing, git: git)
        #expect(code == 0)
        #expect(store.saved?.repos.count == 1)
        #expect(store.saved?.repos.first?.main == true)
        #expect(store.saved?.repos.first?.wipName == "Save")
    }

    @Test func reAddStillHonoursAnExplicitMainFlag() throws {
        let git = FakeGitClient(["/tmp": .init(), "/private/tmp": .init()])
        let existing = Config(repos: [RepoEntry(repoPath: "/tmp", wipName: "Save", main: true)])
        let (code, store) = try perform(["--add", "/private/tmp", "--main", "false"], config: existing, git: git)
        #expect(code == 0)
        #expect(store.saved?.repos.first?.main == false)
        #expect(store.saved?.repos.first?.wipName == "Save")
    }

    @Test func ignoreAddsAFolderAndExits() throws {
        let (code, store) = try perform(["--ignore", "add", "node_modules"], config: Config())
        #expect(code == 0)
        #expect(store.saved?.ignoredFolders == ["node_modules"])
    }

    @Test func ignoreDotResolvesToCurrentDirectory() throws {
        let cwd = FileManager.default.currentDirectoryPath
        let (code, store) = try perform(["--ignore", "add", "."], config: Config())
        #expect(code == 0)
        #expect(store.saved?.ignoredFolders == [cwd])
    }

    @Test func ignoringTheSameFolderTwiceFails() throws {
        let existing = Config(ignoredFolders: ["node_modules"])
        let (code, store) = try perform(["--ignore", "add", "node_modules"], config: existing)
        #expect(code == 1)
        #expect(store.saved == nil)
    }

    @Test func ignoreAddsMultipleFoldersInOneCall() throws {
        let (code, store) = try perform(["--ignore", "add", ".build", ".git", ".vscode"], config: Config())
        #expect(code == 0)
        #expect(store.saved?.ignoredFolders == [".build", ".git", ".vscode"])
    }

    @Test func ignoreAddStripsStrayTrailingCommas() throws {
        let (code, store) = try perform(["--ignore", "add", ".build,", ".git,", ".vscode"], config: Config())
        #expect(code == 0)
        #expect(store.saved?.ignoredFolders == [".build", ".git", ".vscode"])
    }

    @Test func ignoreAddReportsAlreadyIgnoredButStillAddsTheRest() throws {
        let existing = Config(ignoredFolders: ["node_modules"])
        let (code, store) = try perform(["--ignore", "add", "node_modules", ".git"], config: existing)
        #expect(code == 1)
        #expect(store.saved?.ignoredFolders == ["node_modules", ".git"])
    }

    @Test func ignoreRemovesMultipleFoldersInOneCall() throws {
        let existing = Config(ignoredFolders: ["node_modules", "build", ".git"])
        let (code, store) = try perform(["--ignore", "remove", "node_modules", ".git"], config: existing)
        #expect(code == 0)
        #expect(store.saved?.ignoredFolders == ["build"])
    }

    @Test func ignoreRemoveRemovesAFolderAndExits() throws {
        let existing = Config(ignoredFolders: ["node_modules", "build"])
        let (code, store) = try perform(["--ignore", "remove", "node_modules"], config: existing)
        #expect(code == 0)
        #expect(store.saved?.ignoredFolders == ["build"])
    }

    @Test func ignoreRemovingAFolderNotIgnoredFails() throws {
        let (code, store) = try perform(["--ignore", "remove", "node_modules"], config: Config())
        #expect(code == 1)
        #expect(store.saved == nil)
    }

    @Test func ignoreListPrintsIgnoredFolders() throws {
        let existing = Config(ignoredFolders: ["node_modules", "build"])
        let (code, store) = try perform(["--ignore", "list"], config: existing)
        #expect(code == 0)
        #expect(store.saved == nil)
    }

    @Test func recursiveAddSkipsAnIgnoredFolderByName() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("homerun-ignore-\(UUID().uuidString)")
        let repoA = root.appendingPathComponent("a")
        let ignoredRepo = root.appendingPathComponent("node_modules/b")
        try FileManager.default.createDirectory(at: repoA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: ignoredRepo, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let git = FakeGitClient([repoA.path: .init(), ignoredRepo.path: .init()])
        let existing = Config(ignoredFolders: ["node_modules"])
        let (code, store) = try perform(["--add", root.path, "--recursive"], config: existing, git: git)
        #expect(code == 0)
        #expect(store.saved?.repos.map(\.repoPath) == [repoA.path])
    }

    @Test func recursiveAddSkipsAnIgnoredFolderByPath() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("homerun-ignore-\(UUID().uuidString)")
        let repoA = root.appendingPathComponent("a")
        let ignoredRepo = root.appendingPathComponent("scratch")
        try FileManager.default.createDirectory(at: repoA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: ignoredRepo, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let git = FakeGitClient([repoA.path: .init(), ignoredRepo.path: .init()])
        let existing = Config(ignoredFolders: [ignoredRepo.path])
        let (code, store) = try perform(["--add", root.path, "--recursive"], config: existing, git: git)
        #expect(code == 0)
        #expect(store.saved?.repos.map(\.repoPath) == [repoA.path])
    }

    @Test func recursiveAddSkipsAFolderNamedInARootGitignore() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("homerun-gitignore-\(UUID().uuidString)")
        let repoA = root.appendingPathComponent("a")
        let ignoredRepo = root.appendingPathComponent("node_modules/b")
        try FileManager.default.createDirectory(at: repoA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: ignoredRepo, withIntermediateDirectories: true)
        try "# a comment\n\nnode_modules\n".write(to: root.appendingPathComponent(".gitignore"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: root) }

        let git = FakeGitClient([repoA.path: .init(), ignoredRepo.path: .init()])
        let (code, store) = try perform(["--add", root.path, "--recursive"], config: Config(), git: git)
        #expect(code == 0)
        #expect(store.saved?.repos.map(\.repoPath) == [repoA.path])
    }

    @Test func recursiveAddSkipsANestedPathNamedInARootGitignore() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("homerun-gitignore-\(UUID().uuidString)")
        let repoA = root.appendingPathComponent("a")
        let ignoredRepo = root.appendingPathComponent("scratch/b")
        try FileManager.default.createDirectory(at: repoA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: ignoredRepo, withIntermediateDirectories: true)
        try "/scratch/\n".write(to: root.appendingPathComponent(".gitignore"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: root) }

        let git = FakeGitClient([repoA.path: .init(), ignoredRepo.path: .init()])
        let (code, store) = try perform(["--add", root.path, "--recursive"], config: Config(), git: git)
        #expect(code == 0)
        #expect(store.saved?.repos.map(\.repoPath) == [repoA.path])
    }

    @Test func recursiveAddIgnoresWildcardAndNegationGitignoreLines() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("homerun-gitignore-\(UUID().uuidString)")
        let repoA = root.appendingPathComponent("a")
        let buildDir = root.appendingPathComponent("build")
        try FileManager.default.createDirectory(at: repoA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)
        try "*.log\n!build\n".write(to: root.appendingPathComponent(".gitignore"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: root) }

        let git = FakeGitClient([repoA.path: .init(), buildDir.path: .init()])
        let (code, store) = try perform(["--add", root.path, "--recursive"], config: Config(), git: git)
        #expect(code == 0)
        #expect(Set(store.saved?.repos.map(\.repoPath) ?? []) == [repoA.path, buildDir.path])
    }

    @Test func recursiveAddWithNoGitignoreIsUnaffected() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("homerun-gitignore-\(UUID().uuidString)")
        let repoA = root.appendingPathComponent("a")
        try FileManager.default.createDirectory(at: repoA, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let git = FakeGitClient([repoA.path: .init()])
        let (code, store) = try perform(["--add", root.path, "--recursive"], config: Config(), git: git)
        #expect(code == 0)
        #expect(store.saved?.repos.map(\.repoPath) == [repoA.path])
    }

    @Test func recursiveAddKeepsMainOnAlreadyTrackedRepos() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("homerun-keepmain-\(UUID().uuidString)")
        let repoA = root.appendingPathComponent("a")
        try FileManager.default.createDirectory(at: repoA, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let git = FakeGitClient([repoA.path: .init()])
        let existing = Config(repos: [RepoEntry(repoPath: repoA.path, wipName: "Save", main: true)])
        let (code, store) = try perform(["--add", root.path, "--recursive"], config: existing, git: git)
        #expect(code == 0)
        #expect(store.saved?.repos.count == 1)
        #expect(store.saved?.repos.first?.main == true)
        #expect(store.saved?.repos.first?.wipName == "Save")
    }
}
