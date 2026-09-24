import SwiftUI

@main
struct HomerunApp: App {
    // MARK: - Environment

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @Environment(\.settingsService) private var settings

    // MARK: - Scene

    var body: some Scene {
        Window(String(localized: "homerun"), id: AppWindow.main.rawValue) {
            RootView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .defaultSize(width: 1000, height: 680)
        .windowResizability(.contentMinSize)

        MenuBarExtra(isInserted: menuBarBinding) {
            MenuBarContentView()
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)
    }

    // MARK: - Helpers

    private var menuBarBinding: Binding<Bool> {
        Binding(
            get: { settings.localSettings.showsMenuBarItem },
            set: { value in settings.updateLocalSettings { $0.showsMenuBarItem = value } }
        )
    }
}
