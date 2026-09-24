import Foundation

@MainActor
@Observable
final class OnboardingService: SingleFlightRefreshing {
    // MARK: - State

    enum LoadState: Equatable {
        case checking
        case blocked([OnboardingRequirement])
        case optional([OnboardingRequirement])
        case ready
    }

    var loadState: LoadState {
        switch (isChecking, requirements.filter(\.isBlocking).isEmpty, requirements.isEmpty) {
        case (true, _, _):
            .checking
        case (false, false, _):
            .blocked(requirements)
        case (false, true, false):
            .optional(requirements)
        case (false, true, true):
            .ready
        }
    }

    private(set) var availability: ToolAvailability = .unknown
    private(set) var signInError: GitHubCLIError?

    var capabilities: Set<AppCapability> {
        OnboardingRequirementUseCase.capabilities(for: availability)
    }

    var showsOnboarding: Bool {
        isChecking == false
            && OnboardingRequirementUseCase.canSkipOnboarding(
                availability: availability,
                hasCompletedOnboarding: settings.localSettings.hasCompletedOnboarding
            ) == false
    }

    // MARK: - SingleFlightRefreshing

    var refreshTask: Task<Void, Never>?

    // MARK: - Private

    private let gitClient: any GitClienting
    private let gitHubClient: any GitHubCLIClienting
    private let settings: SettingsService

    private var isChecking = true
    private var requirements: [OnboardingRequirement] = []
    private var hasStarted = false

    // MARK: - Init

    init(gitClient: any GitClienting, gitHubClient: any GitHubCLIClienting, settings: SettingsService) {
        self.gitClient = gitClient
        self.gitHubClient = gitHubClient
        self.settings = settings
    }

    // MARK: - Intent

    func start() async {
        guard hasStarted == false else {
            return
        }

        hasStarted = true
        await refresh()
    }

    func signIn() async {
        signInError = nil

        do {
            try await gitHubClient.beginInteractiveSignIn()
        } catch {
            signInError = error
        }
    }

    func markCompleted() {
        settings.updateLocalSettings { $0.hasCompletedOnboarding = true }
    }

    // MARK: - SingleFlightRefreshing

    func performRefresh() async {
        isChecking = true

        let isGitAvailable = await gitClient.isAvailable()
        let isGitHubCLIAvailable = await gitHubClient.isAvailable()
        let accounts = await isGitHubCLIAvailable ? (try? gitHubClient.accounts()) ?? [] : []

        guard Task.isCancelled == false else {
            return
        }

        availability = ToolAvailability(
            isGitAvailable: isGitAvailable,
            isGitHubCLIAvailable: isGitHubCLIAvailable,
            gitHubAccounts: accounts
        )
        requirements = OnboardingRequirementUseCase.requirements(for: availability)
        isChecking = false
    }
}
