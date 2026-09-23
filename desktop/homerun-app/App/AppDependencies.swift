import Foundation
import SwiftData

enum AppDependencies {
    // MARK: - Graph

    @MainActor
    static let shared = makeGraph()

    @MainActor
    static func makeGraph() -> AppGraph {
        let fileManager = FileManager.default
        let defaults = UserDefaults.standard
        let processEnvironment = ProcessInfo.processInfo.environment
        let temporaryDirectory = fileManager.temporaryDirectory
        let resolver = ToolPathResolver(fileManager: fileManager, searchDirectories: AppConstants.toolSearchDirectories)

        let localStore = UserDefaultsLocalSettingsStore(defaults: defaults, defaultSettings: makeDefaultLocalSettings(resolver))
        let sharedStore = makeSharedStore()
        let settings = SettingsService(sharedStore: sharedStore, localStore: localStore)

        let commandRunner = ProcessCommandRunner(
            baseEnvironment: processEnvironment,
            temporaryDirectory: temporaryDirectory
        )
        let gitClient = ProcessGitClient(
            commandRunner: commandRunner,
            gitPath: resolver.resolve("git", preferring: settings.localSettings.gitPath) ?? "/usr/bin/git"
        )
        let gitHubClient = ProcessGitHubCLIClient(
            commandRunner: commandRunner,
            gitHubCLIPath: resolver.resolve("gh", preferring: settings.localSettings.gitHubCLIPath) ?? "/opt/homebrew/bin/gh",
            scriptRunnerPath: resolver.resolve("osascript", preferring: nil) ?? "/usr/bin/osascript"
        )
        let clock = SystemClock(timeZone: TimeZone.current)

        let repositories = RepositoriesService(
            sharedStore: sharedStore,
            gitClient: gitClient,
            discovery: FileSystemRepositoryDiscovery(fileManager: fileManager),
            readinessChecker: GitReadinessChecker(gitClient: gitClient, fileManager: fileManager),
            fileManager: fileManager,
            clock: clock,
            settings: settings
        )

        let engine = RepositorySyncEngine(
            gitClient: gitClient,
            gitHubClient: gitHubClient,
            pushFallback: GitHubAccountPushFallback(gitClient: gitClient, gitHubClient: gitHubClient)
        )

        return AppGraph(
            settings: settings,
            onboarding: OnboardingService(gitClient: gitClient, gitHubClient: gitHubClient, settings: settings),
            repositories: repositories,
            sync: SyncService(engine: engine, repositories: repositories, settings: settings, clock: clock),
            resume: ResumeService(
                gitClient: gitClient,
                repositories: repositories,
                settings: settings,
                projectOpener: WorkspaceProjectOpener()
            ),
            workspace: WorkspaceService(
                manifestStore: FileWorkspaceManifestStore(),
                sharedStore: sharedStore,
                repositories: repositories,
                settings: settings,
                clock: clock
            ),
            accounts: GitHubAccountsService(client: gitHubClient, repositories: repositories, settings: settings),
            cleaner: CleanerService(
                runtimeProvider: SimctlRuntimeProvider(
                    commandRunner: commandRunner,
                    xcrunPath: resolver.resolve("xcrun", preferring: nil) ?? "/usr/bin/xcrun"
                ),
                derivedDataProvider: FileSystemDerivedDataProvider(
                    fileManager: fileManager,
                    defaultDerivedDataURL: makeDefaultDerivedDataURL(fileManager)
                ),
                repositories: repositories,
                settings: settings
            ),
            filePanel: AppKitFilePanelPresenter()
        )
    }

    // MARK: - Private

    @MainActor
    private static func makeSharedStore() -> any SharedWorkspaceStoring {
        let identifier = Bundle.main.object(forInfoDictionaryKey: AppConstants.cloudKitContainerInfoKey) as? String

        do {
            let container = try ModelContainerFactory.make(inMemory: false, cloudKitContainerIdentifier: identifier)

            return SwiftDataWorkspaceStore(context: ModelContext(container))
        } catch {
            AppLog.error("Falling back to an in-memory workspace: \(String(describing: error))")

            return makeInMemoryStore()
        }
    }

    @MainActor
    private static func makeInMemoryStore() -> any SharedWorkspaceStoring {
        guard let container = try? ModelContainerFactory.make(inMemory: true, cloudKitContainerIdentifier: nil) else {
            fatalError("The workspace store could not be created")
        }

        return SwiftDataWorkspaceStore(context: ModelContext(container))
    }

    private static func makeDefaultLocalSettings(_ resolver: ToolPathResolver) -> LocalSettings {
        var settings = LocalSettings.default
        settings.gitPath = resolver.resolve("git", preferring: nil) ?? settings.gitPath
        settings.gitHubCLIPath = resolver.resolve("gh", preferring: nil) ?? settings.gitHubCLIPath

        return settings
    }

    private static func makeDefaultDerivedDataURL(_ fileManager: FileManager) -> URL {
        let home = fileManager.homeDirectoryForCurrentUser

        return home.appending(path: "Library/Developer/Xcode/DerivedData")
    }
}
