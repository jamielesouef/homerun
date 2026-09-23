import Foundation
import Testing
@testable import homerun_app

@Suite("RepositoriesService", .tags(.service))
struct RepositoriesServiceTests {
    // MARK: - Loading

    @Test("reports an empty shared workspace rather than a loading state that never ends")
    @MainActor
    func reportsEmptyWorkspace() async {
        let harness = ServiceHarness()

        await harness.repositories.start()

        #expect(harness.repositories.loadState == .empty)
    }

    @Test("joins the shared entry to this Mac's checkout and its snapshot")
    @MainActor
    func joinsSharedAndLocal() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot(ahead: 2))

        await harness.repositories.start()

        #expect(harness.repositories.repositories.first?.status == .ahead)
        #expect(harness.repositories.repositories.first?.isCloned == true)
    }

    @Test("treats a shared entry with no checkout here as not cloned, keeping it in the workspace")
    @MainActor
    func keepsUnclonedEntries() async {
        let harness = ServiceHarness()
        harness.addUnclonedRepository("a", name: "app")

        await harness.repositories.start()

        #expect(harness.repositories.repositories.first?.status == .notCloned)
        #expect(harness.sharedStore.repositories.count == 1)
    }

    @Test("records a repository it could not read rather than dropping it")
    @MainActor
    func recordsUnreadableRepository() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: nil)

        await harness.repositories.start()

        #expect(harness.repositories.repositories.first?.status == .unreadable)
    }

    @Test("surfaces a shared store failure")
    @MainActor
    func surfacesStoreFailure() async {
        let harness = ServiceHarness()
        harness.sharedStore.loadFailure = .fetchFailed("offline")

        await harness.repositories.start()

        #expect(harness.repositories.loadState == .error(.fetchFailed("offline")))
    }

    // MARK: - Filtering

    @Test("starts on the default filter and sort order from the shared preferences")
    @MainActor
    func startsFromPreferences() {
        let harness = ServiceHarness()
        harness.sharedStore.preferences.defaultRepositoryStatusFilter = .dirty
        harness.sharedStore.preferences.repositorySortOrder = .lastSynced
        let settings = SettingsService(sharedStore: harness.sharedStore, localStore: harness.localStore)

        let service = RepositoriesService(
            sharedStore: harness.sharedStore,
            gitClient: harness.gitClient,
            discovery: harness.discovery,
            readinessChecker: harness.readinessChecker,
            fileManager: .default,
            clock: harness.clock,
            settings: settings
        )

        #expect(service.filter == .dirty)
        #expect(service.sortOrder == .lastSynced)
    }

    @Test("hides clean repositories when the preference says to")
    @MainActor
    func hidesCleanRepositories() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "clean", snapshot: RepositoryFixtures.snapshot())
        await harness.addRepository("b", name: "dirty", snapshot: RepositoryFixtures.snapshot(untracked: ["A"]))
        await harness.repositories.start()

        harness.settings.updatePreferences { $0.showsCleanRepositories = false }

        #expect(harness.repositories.visibleRepositories.map(\.name) == ["dirty"])
    }

    // MARK: - Discovery

    @Test("scans with the configured ignored folder names")
    @MainActor
    func scansWithIgnoredFolders() async {
        let harness = ServiceHarness()
        harness.settings.updatePreferences { $0.ignoredFolderNames = ["Pods"] }

        _ = await harness.repositories.scanFolder(URL(filePath: "/dev"))

        #expect(await harness.discovery.ignoredFolderNames == ["Pods"])
    }

    @Test("refuses a folder that is not a git repository")
    @MainActor
    func refusesNonRepository() async {
        let harness = ServiceHarness()

        let added = await harness.repositories.addRepository(at: URL(filePath: "/dev/not-a-repo"))

        #expect(added == false)
        #expect(harness.sharedStore.repositories.isEmpty)
    }

    @Test("adds a discovered repository keyed on its remote and records this Mac's path")
    @MainActor
    func addsDiscoveredRepository() async {
        let harness = ServiceHarness()
        let directory = harness.makeDirectory("app")
        await harness.gitClient.setSnapshot(RepositoryFixtures.snapshot(), at: directory)

        await harness.repositories.add([DiscoveredRepository(url: directory)])

        #expect(harness.sharedStore.repositories.first?.identifier == "remote:github.com/acme/app")
        #expect(harness.localStore.settings.repositoryPaths["remote:github.com/acme/app"] != nil)
    }

    @Test("preserves the settings of a repository that is added again")
    @MainActor
    func preservesSettingsOnReAdd() async throws {
        let harness = ServiceHarness()
        let directory = harness.makeDirectory("app")
        await harness.gitClient.setSnapshot(RepositoryFixtures.snapshot(), at: directory)
        await harness.repositories.add([DiscoveredRepository(url: directory)])
        var stored = try #require(harness.sharedStore.repositories.first)
        stored.wipCommitPrefixOverride = "SCRATCH"
        try harness.sharedStore.upsert(stored)

        await harness.repositories.add([DiscoveredRepository(url: directory)])

        #expect(harness.sharedStore.repositories.count == 1)
        #expect(harness.sharedStore.repositories.first?.wipCommitPrefixOverride == "SCRATCH")
    }

    // MARK: - Maintenance

    @Test("removing a shared entry deletes no files and clears this Mac's path")
    @MainActor
    func removesSharedEntryOnly() async {
        let harness = ServiceHarness()
        let directory = await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot())
        await harness.repositories.start()

        harness.repositories.removeFromSharedWorkspace(identifier: "a")

        #expect(harness.sharedStore.removedIdentifiers == ["a"])
        #expect(harness.localStore.settings.repositoryPaths["a"] == nil)
        #expect(FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)))
        #expect(harness.repositories.repositories.isEmpty)
        #expect(harness.repositories.loadState == .empty)
    }

    @Test("publishes a newly added repository without waiting for another load")
    @MainActor
    func publishesAddedRepositoryImmediately() async {
        let harness = ServiceHarness()
        await harness.repositories.start()
        let directory = harness.makeDirectory("igloo")
        await harness.gitClient.setSnapshot(RepositoryFixtures.snapshot(), at: directory)

        await harness.repositories.add([DiscoveredRepository(url: directory)])

        #expect(harness.repositories.repositories.map(\.name) == ["igloo"])
        #expect(harness.repositories.visibleRepositories.map(\.name) == ["igloo"])
        #expect(harness.repositories.repositories.first?.snapshot != nil)
    }

    @Test("shows a dropped repository straight away, before its status has been read")
    @MainActor
    func showsRepositoryWhileItsStatusLoads() async {
        let harness = ServiceHarness()
        await harness.repositories.start()
        let directory = harness.makeDirectory("igloo")
        await harness.gitClient.setSnapshot(RepositoryFixtures.snapshot(), at: directory)
        await harness.gitClient.holdSnapshots()

        let adding = Task { await harness.repositories.add([DiscoveredRepository(url: directory)]) }
        await harness.gitClient.waitUntilSnapshotRequested()

        #expect(harness.repositories.repositories.map(\.name) == ["igloo"])
        #expect(harness.repositories.repositories.first?.status == .loading)

        await harness.gitClient.releaseSnapshots()
        await adding.value

        #expect(harness.repositories.repositories.first?.status == .clean)
    }

    @Test("reads only the repository that was added rather than every tracked one")
    @MainActor
    func readsOnlyTheAddedRepository() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "existing", snapshot: RepositoryFixtures.snapshot())
        await harness.repositories.start()
        let directory = harness.makeDirectory("igloo")
        await harness.gitClient.setSnapshot(RepositoryFixtures.snapshot(), at: directory)
        let snapshotsBefore = await harness.gitClient.calls.count(where: { $0 == "snapshot" })

        await harness.repositories.add([DiscoveredRepository(url: directory)])

        let snapshotsAfter = await harness.gitClient.calls.count(where: { $0 == "snapshot" })
        #expect(snapshotsAfter - snapshotsBefore == 1)
        #expect(harness.repositories.repositories.count == 2)
    }

    @Test("removing takes the row out without re-reading the repositories that remain")
    @MainActor
    func removesWithoutRereadingTheRest() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "going", snapshot: RepositoryFixtures.snapshot())
        await harness.addRepository("b", name: "staying", snapshot: RepositoryFixtures.snapshot())
        await harness.repositories.start()
        let snapshotsBefore = await harness.gitClient.calls.count(where: { $0 == "snapshot" })

        harness.repositories.removeFromSharedWorkspace(identifier: "a")

        #expect(harness.repositories.repositories.map(\.name) == ["staying"])
        #expect(await harness.gitClient.calls.count(where: { $0 == "snapshot" }) == snapshotsBefore)
    }

    @Test("removing this Mac's path leaves the shared workspace entry in place")
    @MainActor
    func removesLocalPathOnly() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot())
        await harness.repositories.start()

        harness.repositories.removeLocalPathMapping(identifier: "a")

        #expect(harness.sharedStore.repositories.count == 1)
        #expect(harness.repositories.repositories.first?.status == .notCloned)
    }

    @Test("removes the path mappings whose folder has gone and nothing else")
    @MainActor
    func removesStaleMappings() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot())
        harness.settings.recordLocalPath(URL(filePath: "/nowhere/gone"), for: "b")

        let stale = harness.repositories.removeStaleLocalPathMappings()

        #expect(stale == ["b"])
        #expect(harness.localStore.settings.repositoryPaths["a"] != nil)
    }

    @Test("removes duplicate shared entries")
    @MainActor
    func removesDuplicates() async {
        let harness = ServiceHarness()
        harness.addUnclonedRepository("a", name: "app")
        harness.sharedStore.repositories.append(RepositoryFixtures.shared("a", name: "app"))

        let removed = harness.repositories.removeDuplicateEntries()

        #expect(removed == ["a"])
        #expect(harness.sharedStore.repositories.count == 1)
    }

    @Test("clearing with local scope keeps the shared workspace intact")
    @MainActor
    func clearsLocalScopeOnly() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot())

        harness.repositories.clearTrackedConfiguration(scope: .local)

        #expect(harness.localStore.settings.repositoryPaths.isEmpty)
        #expect(harness.sharedStore.repositories.count == 1)
        #expect(harness.sharedStore.clearedAllCount == 0)
    }

    @Test("clearing with shared scope empties the workspace on every Mac")
    @MainActor
    func clearsSharedScope() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot())

        harness.repositories.clearTrackedConfiguration(scope: .shared)

        #expect(harness.sharedStore.repositories.isEmpty)
        #expect(harness.localStore.settings.repositoryPaths.isEmpty)
    }

    // MARK: - Sync results

    @Test("records the branch and commit of a successful push for use when resuming elsewhere")
    @MainActor
    func recordsHandoff() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot())
        await harness.repositories.start()

        await harness.repositories.apply([
            RepositorySyncOutcome(
                identifier: "a",
                result: .succeeded(commit: "abc123", branch: "feature/login"),
                finishedAt: Date(timeIntervalSince1970: 500)
            )
        ])

        let stored = harness.sharedStore.repositories.first
        #expect(stored?.handoff == RepositoryHandoff(branch: "feature/login", commit: "abc123", recordedAt: Date(timeIntervalSince1970: 500)))
        #expect(stored?.lastSuccessfulSyncDate == Date(timeIntervalSince1970: 500))
    }

    @Test("records no handoff for a failed sync and marks the repository as failed")
    @MainActor
    func recordsFailure() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot())
        await harness.repositories.start()

        await harness.repositories.apply([
            RepositorySyncOutcome(identifier: "a", result: .failed(.diverged), finishedAt: .distantPast)
        ])

        #expect(harness.sharedStore.repositories.first?.handoff == nil)
        #expect(harness.repositories.repositories.first?.status == .failed)
    }

    // MARK: - Readiness

    @Test("stores the readiness report against the repository it describes")
    @MainActor
    func storesReadinessReport() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot())
        await harness.repositories.start()
        let report = ReadinessReport(identifier: "a", currentBranchPushed: true, issues: [.missingSetupInstructions])
        await harness.readinessChecker.setReport(report, for: "a")

        await harness.repositories.evaluateReadinessForAll(checksRemoteTags: false)

        #expect(harness.repositories.readinessReports["a"] == report)
    }

    @Test("does not evaluate readiness for a repository that is not cloned here")
    @MainActor
    func skipsReadinessForUncloned() async {
        let harness = ServiceHarness()
        harness.addUnclonedRepository("a", name: "app")
        await harness.repositories.start()

        await harness.repositories.evaluateReadinessForAll(checksRemoteTags: false)

        #expect(await harness.readinessChecker.inputs.isEmpty)
    }
}
