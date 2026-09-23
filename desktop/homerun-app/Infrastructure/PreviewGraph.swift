#if DEBUG
import Foundation

@MainActor
enum PreviewGraph {
    // MARK: - Graphs

    static let populated = make(repositories: sampleRepositories, paths: samplePaths, snapshots: sampleSnapshots)

    static let empty = make(repositories: [], paths: [:], snapshots: [:])

    static let longNames = make(
        repositories: [
            WorkspaceRepository(
                identifier: "remote:github.com/acme/an-extremely-long-repository-name-that-wraps",
                name: "an-extremely-long-repository-name-that-wraps-onto-several-lines",
                remoteURL: "https://github.com/acme/an-extremely-long-repository-name-that-wraps.git",
                preferredRelativePath: "clients/acme/an-extremely-long-repository-name-that-wraps"
            )
        ],
        paths: ["remote:github.com/acme/an-extremely-long-repository-name-that-wraps": "/Users/preview/Developer/long"],
        snapshots: [
            "/Users/preview/Developer/long": snapshot(
                branch: "feature/a-very-long-branch-name-for-a-very-long-piece-of-work",
                ahead: 12,
                tracked: [GitFileChange(path: "Sources/A/Very/Deeply/Nested/File.swift", status: .modified)],
                untracked: ["Notes/scratch-thoughts-about-the-thing.md"]
            )
        ]
    )

    // MARK: - Factory

    static func make(
        repositories: [WorkspaceRepository],
        paths: [String: String],
        snapshots: [String: GitRepositorySnapshot],
        gitHubAvailable: Bool = true
    ) -> AppGraph {
        var local = LocalSettings.default
        local.repositoryPaths = paths
        local.workspaceRootPath = "/Users/preview/Developer"
        local.hasCompletedOnboarding = true

        let sharedStore = MockSharedWorkspaceStore(repositories: repositories)
        let localStore = MockLocalSettingsStore(settings: local)
        let settings = SettingsService(sharedStore: sharedStore, localStore: localStore)

        var gitClient = MockGitClient()
        gitClient.snapshotsByPath = snapshots
        gitClient.commits = sampleCommits

        var gitHubClient = MockGitHubCLIClient()
        gitHubClient.available = gitHubAvailable

        let clock = MockClock()
        let repositoriesService = RepositoriesService(
            sharedStore: sharedStore,
            gitClient: gitClient,
            discovery: MockRepositoryDiscovery(),
            readinessChecker: MockReadinessChecker(issues: [.untrackedFiles(["Notes.md"])]),
            fileManager: .default,
            clock: clock,
            settings: settings
        )

        return AppGraph(
            settings: settings,
            onboarding: OnboardingService(gitClient: gitClient, gitHubClient: gitHubClient, settings: settings),
            repositories: repositoriesService,
            sync: SyncService(engine: MockSyncEngine(), repositories: repositoriesService, settings: settings, clock: clock),
            resume: ResumeService(
                gitClient: gitClient,
                repositories: repositoriesService,
                settings: settings,
                projectOpener: MockProjectOpener()
            ),
            workspace: WorkspaceService(
                manifestStore: MockWorkspaceManifestStore(),
                sharedStore: sharedStore,
                repositories: repositoriesService,
                settings: settings,
                clock: clock
            ),
            accounts: GitHubAccountsService(client: gitHubClient, repositories: repositoriesService, settings: settings),
            cleaner: CleanerService(
                runtimeProvider: MockSimulatorRuntimeProvider(),
                derivedDataProvider: MockDerivedDataProvider(),
                repositories: repositoriesService,
                settings: settings
            ),
            filePanel: MockFilePanelPresenter()
        )
    }

    // MARK: - Samples

    static let sampleRepositories: [WorkspaceRepository] = [
        WorkspaceRepository(
            identifier: "remote:github.com/acme/app",
            name: "app",
            remoteURL: "https://github.com/acme/app.git",
            preferredRelativePath: "app",
            lastSuccessfulSyncDate: Date(timeIntervalSince1970: 1_758_500_000)
        ),
        WorkspaceRepository(
            identifier: "remote:github.com/acme/tooling",
            name: "tooling",
            remoteURL: "git@github.com:acme/tooling.git",
            preferredRelativePath: "tooling"
        ),
        WorkspaceRepository(
            identifier: "remote:github.com/acme/archive",
            name: "archive",
            remoteURL: "https://github.com/acme/archive.git",
            preferredRelativePath: "archive"
        )
    ]

    static let samplePaths = [
        "remote:github.com/acme/app": "/Users/preview/Developer/app",
        "remote:github.com/acme/tooling": "/Users/preview/Developer/tooling"
    ]

    static let sampleSnapshots = [
        "/Users/preview/Developer/app": snapshot(
            branch: "feature/login",
            ahead: 3,
            tracked: [
                GitFileChange(path: "Sources/Login.swift", status: .modified),
                GitFileChange(path: "Sources/Removed.swift", status: .deleted)
            ],
            untracked: ["Notes.md"]
        ),
        "/Users/preview/Developer/tooling": snapshot(branch: "main")
    ]

    static let sampleCommits = [
        GitCommitSummary(
            hash: "abc1234def5678",
            subject: "Add the login screen",
            authorName: "Jamie",
            date: Date(timeIntervalSince1970: 1_758_500_000)
        ),
        GitCommitSummary(
            hash: "bcd2345efa6789",
            subject: "Tidy the session store",
            authorName: "Jamie",
            date: Date(timeIntervalSince1970: 1_758_400_000)
        )
    ]

    // MARK: - Helpers

    static func snapshot(
        branch: String?,
        ahead: Int = 0,
        behind: Int = 0,
        tracked: [GitFileChange] = [],
        untracked: [String] = []
    ) -> GitRepositorySnapshot {
        GitRepositorySnapshot(
            currentBranch: branch,
            headCommit: "abc1234",
            defaultRemoteName: "origin",
            remoteURL: "https://github.com/acme/app.git",
            upstreamBranch: branch.map { "origin/\($0)" },
            aheadCount: ahead,
            behindCount: behind,
            workingTree: GitWorkingTreeStatus(trackedChanges: tracked, untrackedPaths: untracked),
            branches: [
                GitBranchRef(name: branch ?? "main", upstream: "origin/\(branch ?? "main")", aheadCount: ahead, behindCount: behind),
                GitBranchRef(name: "spike", upstream: nil, aheadCount: 0, behindCount: 0)
            ],
            submoduleChanges: []
        )
    }
}
#endif
