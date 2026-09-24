import SwiftUI

struct TodaySettingsSection: View {
    // MARK: - Environment

    @Environment(\.settingsService) private var settings

    // MARK: - View

    var body: some View {
        Section(String(localized: "Today")) {
            Picker(String(localized: "Default status filter"), selection: filterBinding) {
                ForEach(RepositoryStatusFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }

            Toggle(String(localized: "Show repositories that are clean and fully synced"), isOn: cleanBinding)
        }
    }

    // MARK: - Helpers

    private var filterBinding: Binding<RepositoryStatusFilter> {
        Binding(
            get: { settings.preferences.defaultRepositoryStatusFilter },
            set: { value in settings.updatePreferences { $0.defaultRepositoryStatusFilter = value } }
        )
    }

    private var cleanBinding: Binding<Bool> {
        Binding(
            get: { settings.preferences.showsCleanRepositories },
            set: { value in settings.updatePreferences { $0.showsCleanRepositories = value } }
        )
    }
}

#if DEBUG
    #Preview("Today settings") {
        Form {
            TodaySettingsSection()
        }
        .formStyle(.grouped)
        .environment(\.settingsService, PreviewGraph.populated.settings)
        .frame(width: 560, height: 200)
    }
#endif
