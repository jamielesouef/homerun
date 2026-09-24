import SwiftUI

struct MenuBarSettingsSection: View {
    // MARK: - Environment

    @Environment(\.settingsService) private var settings

    // MARK: - View

    var body: some View {
        Section(String(localized: "Menu bar")) {
            Toggle(String(localized: "Show the menu bar item on this Mac"), isOn: showsMenuBarBinding)

            Toggle(String(localized: "Show a count of repositories with work only here"), isOn: countBinding)
                .disabled(settings.localSettings.showsMenuBarItem == false)

            Toggle(String(localized: "Keep homerun running when the window closes"), isOn: keepsRunningBinding)
        }
    }

    // MARK: - Helpers

    private var showsMenuBarBinding: Binding<Bool> {
        Binding(
            get: { settings.localSettings.showsMenuBarItem },
            set: { value in settings.updateLocalSettings { $0.showsMenuBarItem = value } }
        )
    }

    private var countBinding: Binding<Bool> {
        Binding(
            get: { settings.preferences.menuBarShowsLocalOnlyCount },
            set: { value in settings.updatePreferences { $0.menuBarShowsLocalOnlyCount = value } }
        )
    }

    private var keepsRunningBinding: Binding<Bool> {
        Binding(
            get: { settings.localSettings.keepsRunningInMenuBarOnClose },
            set: { value in settings.updateLocalSettings { $0.keepsRunningInMenuBarOnClose = value } }
        )
    }
}

#if DEBUG
    #Preview("Menu bar settings") {
        Form {
            MenuBarSettingsSection()
        }
        .formStyle(.grouped)
        .environment(\.settingsService, PreviewGraph.populated.settings)
        .frame(width: 560, height: 200)
    }
#endif
