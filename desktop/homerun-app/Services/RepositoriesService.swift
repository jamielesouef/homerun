import Foundation

@MainActor
@Observable
final class RepositoriesService: SingleFlightRefreshing {
    // MARK: - State

    enum LoadState: Equatable {
        case loading
        case error(PersistenceError)
        case empty
        case loaded([TrackedRepository])
    }

    var loadState: LoadState {
        switch (isLoading, loadError, repositories.isEmpty) {
        case (true, _, true):
            .loading
        case (_, let error?, true):
            .error(error)
        case (_, nil, true):
            .empty
        case (_, _, false):
            .loaded(repositories)
        }
    }

    private(set) var repositories: [TrackedRepository] = []
    private(set) var readinessReports: [String: ReadinessReport] = [:]
    private(set) var isScanning = false
    private(set) var lastMaintenanceMessage: String?

    var filter: RepositoryStatusFilter
    var sortOrder: RepositorySortOrder
    var searchText = ""

    var visibleRepositories: [TrackedRepository] {
        RepositorySortUseCase.sorted(
            RepositoryFilterUseCase.apply(
                to: repositories,
                filter: filter,
                showsCleanRepositories: settings.preferences.showsCleanRepositories,
                searchText: searchText
            ),
            by: sortOrder
        )
    }

    var todaySummary: TodaySummary {
        TodaySummaryUseCase.summary(for: repositories, readiness: readinessReports)
    }

    // MARK: - SingleFlightRefreshing

    var refreshTask: Task<Void, Never>?

    // MARK: - Private

    private let sharedStore: any SharedWorkspaceStoring
    private let gitClient: any GitClienting
    private let discovery: any RepositoryDiscovering
    private let readinessChecker: any ReadinessChecking
    private let fileManager: FileManager
    private let clock: any Clocking
    private let settings: SettingsService

    private var outcomes: [String: RepositorySyncOutcome] = [:]
    private var isLoading = false
    private var loadError: PersistenceError?
    private var hasStarted = false

    // MARK: - Init

    init(
        sharedStore: any SharedWorkspaceStoring,
        gitClient: any GitClienting,
        discovery: any RepositoryDiscovering,
        readinessChecker: any ReadinessChecking,
        fileManager: FileManager,
        clock: any Clocking,
        settings: SettingsService
    ) {
        self.sharedStore = sharedStore
        self.gitClient = gitClient
        self.discovery = discovery
        self.readinessChecker = readinessChecker
        self.fileManager = fileManager
        self.clock = clock
        self.settings = settings
        filter = settings.preferences.defaultRepositoryStatusFilter
        sortOrder = settings.preferences.repositorySortOrder
    }

    // MARK: - Intent

    func start() async {
        guard hasStarted == false else {
            return
        }

        hasStarted = true
        await refresh()
    }

    func repository(identifier: String) -> TrackedRepository? {
        repositories.first { $0.id == identifier }
    }

    func update(_ repository: WorkspaceRepository) async {
        store { () throws(PersistenceError) in
            try sharedStore.upsert(repository)
        }
        await refresh()
    }

    func addRepository(at url: URL) async -> Bool {
        let standardised = url.standardizedFileURL

        guard await gitClient.isRepository(at: standardised) else {
            lastMaintenanceMessage = String(localized: "\(standardised.lastPathComponent) is not a git repository.")
            return false
        }

        await add([DiscoveredRepository(url: standardised)])

        return true
    }

    func scanFolder(_ url: URL) async -> [DiscoveredRepository] {
        isScanning = true
        defer { isScanning = false }

        let ignored = Set(settings.preferences.ignoredFolderNames)
        let found = await discovery.discoverRepositories(in: url, ignoredFolderNames: ignored, maximumDepth: 6)

        guard Task.isCancelled == false else {
            return []
        }

        return found
    }

    func add(_ discovered: [DiscoveredRepository]) async {
        let existing = (try? sharedStore.loadRepositories()) ?? []

        for repository in RepositoryMaintenanceUseCase.deduplicated(discovered) {
            let remoteURL = try? await gitClient.remoteURL(at: repository.url)
            let identifier = WorkspaceIdentifier.make(remoteURL: remoteURL, folderName: repository.name)
            let merged = RepositoryMaintenanceUseCase.merged(
                existing: existing.first { $0.identifier == identifier },
                discovered: repository,
                remoteURL: remoteURL,
                addedDate: clock.now()
            )

            store { () throws(PersistenceError) in
            try sharedStore.upsert(merged)
        }
            settings.recordLocalPath(repository.url, for: identifier)
        }

        await refresh()
    }

    // MARK: - Maintenance

    func removeFromSharedWorkspace(identifier: String) async {
        store { () throws(PersistenceError) in
            try sharedStore.remove(identifier: identifier)
        }
        settings.removeLocalPath(for: identifier)
        lastMaintenanceMessage = String(localized: "Removed from the shared workspace. No files were deleted.")
        await refresh()
    }

    func removeLocalPathMapping(identifier: String) async {
        settings.removeLocalPath(for: identifier)
        lastMaintenanceMessage = String(localized: "Removed this Mac's path. The shared workspace entry is unchanged.")
        await refresh()
    }

    func removeStaleLocalPathMappings() async -> [String] {
        let stale = RepositoryMaintenanceUseCase.staleLocalPathIdentifiers(
            repositoryPaths: settings.localSettings.repositoryPaths
        ) { [fileManager] path in
            fileManager.fileExists(atPath: path)
        }

        for identifier in stale {
            settings.removeLocalPath(for: identifier)
        }

        lastMaintenanceMessage = String(localized: "Removed \(stale.count) stale path(s) on this Mac.")
        await refresh()

        return stale
    }

    func removeDuplicateEntries() async -> [String] {
        var removed: [String] = []
        store { () throws(PersistenceError) in
            removed = try sharedStore.removeDuplicates()
        }
        lastMaintenanceMessage = String(localized: "Removed \(removed.count) duplicate entry(s).")
        await refresh()

        return removed
    }

    func clearTrackedConfiguration(scope: ConfigurationScope) async {
        switch scope {
        case .local:
            settings.updateLocalSettings { $0.repositoryPaths = [:] }
        case .shared:
            store { () throws(PersistenceError) in
            try sharedStore.removeAllRepositories()
        }
            settings.updateLocalSettings { $0.repositoryPaths = [:] }
        }

        lastMaintenanceMessage = scope.explanation
        await refresh()
    }

    func clearMaintenanceMessage() {
        lastMaintenanceMessage = nil
    }

    // MARK: - Sync results

    func apply(_ outcomes: [RepositorySyncOutcome]) async {
        for outcome in outcomes {
            self.outcomes[outcome.identifier] = outcome
            record(outcome)
        }

        await refresh()
    }

    // MARK: - Detail

    func recentCommits(for repository: TrackedRepository, limit: Int) async -> [GitCommitSummary] {
        guard let directory = repository.localPath else {
            return []
        }

        return (try? await gitClient.recentCommits(at: directory, limit: limit)) ?? []
    }

    func diffSummary(for repository: TrackedRepository) async -> String {
        guard let directory = repository.localPath else {
            return ""
        }

        return (try? await gitClient.diffSummary(at: directory)) ?? ""
    }

    // MARK: - Readiness

    func evaluateReadiness(for repository: TrackedRepository, checksRemoteTags: Bool) async {
        guard let directory = repository.localPath, let snapshot = repository.snapshot else {
            return
        }

        let input = ReadinessCheckInput(
            repository: repository.shared,
            directory: directory,
            snapshot: snapshot,
            checksRemoteTags: checksRemoteTags
        )
        let report = await readinessChecker.evaluate(input)

        guard Task.isCancelled == false else {
            return
        }

        readinessReports[repository.id] = report
    }

    func evaluateReadinessForAll(checksRemoteTags: Bool) async {
        for repository in repositories where repository.isCloned {
            await evaluateReadiness(for: repository, checksRemoteTags: checksRemoteTags)
        }
    }

    // MARK: - SingleFlightRefreshing

    func performRefresh() async {
        isLoading = true
        loadError = nil

        let shared: [WorkspaceRepository]

        do {
            shared = try sharedStore.loadRepositories()
        } catch {
            loadError = error
            isLoading = false
            return
        }

        let paths = settings.localSettings.repositoryPaths
        let loaded = await load(shared, paths: paths)

        guard Task.isCancelled == false else {
            return
        }

        repositories = loaded
        isLoading = false
    }

    // MARK: - Helpers

    private func load(_ shared: [WorkspaceRepository], paths: [String: String]) async -> [TrackedRepository] {
        var loaded: [TrackedRepository] = []

        for repository in shared {
            loaded.append(await tracked(repository, path: paths[repository.identifier]))
        }

        return loaded
    }

    private func tracked(_ repository: WorkspaceRepository, path: String?) async -> TrackedRepository {
        guard let path, fileManager.fileExists(atPath: path) else {
            return TrackedRepository(shared: repository, lastSyncOutcome: outcomes[repository.identifier])
        }

        let directory = URL(filePath: path)
        let outcome = outcomes[repository.identifier]

        do {
            let snapshot = try await gitClient.snapshot(at: directory)

            return TrackedRepository(
                shared: repository,
                localPath: directory,
                snapshot: snapshot,
                lastSyncOutcome: outcome
            )
        } catch {
            return TrackedRepository(
                shared: repository,
                localPath: directory,
                lastSyncOutcome: outcome,
                readError: error
            )
        }
    }

    private func record(_ outcome: RepositorySyncOutcome) {
        guard case .succeeded(let commit, let branch) = outcome.result else {
            return
        }

        guard var repository = try? sharedStore.repository(identifier: outcome.identifier) else {
            return
        }

        repository.lastSuccessfulSyncDate = outcome.finishedAt

        if let commit, let branch {
            repository.handoff = RepositoryHandoff(branch: branch, commit: commit, recordedAt: outcome.finishedAt)
        }

        store { () throws(PersistenceError) in
            try sharedStore.upsert(repository)
        }
    }

    private func store(_ work: () throws(PersistenceError) -> Void) {
        do {
            try work()
            loadError = nil
        } catch {
            loadError = error
            AppLog.error("Shared workspace write failed: \(String(describing: error))")
        }
    }
}
