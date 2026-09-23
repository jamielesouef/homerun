import Foundation
@testable import homerun_app

@MainActor
final class StubLocalSettingsStore: LocalSettingsStoring {
    // MARK: - State

    var settings: LocalSettings
    private(set) var saveCount = 0

    // MARK: - Init

    init(settings: LocalSettings = .default) {
        self.settings = settings
    }

    // MARK: - LocalSettingsStoring

    func load() -> LocalSettings {
        settings
    }

    func save(_ settings: LocalSettings) {
        self.settings = settings
        saveCount += 1
    }
}
