import SwiftUI

struct RepositorySettingsSection: View {
    // MARK: - Environment

    @Environment(\.settingsService) private var settings

    // MARK: - View

    var body: some View {
        Section(String(localized: "Repositories")) {
            Toggle(String(localized: "Ask me to confirm before syncing"), isOn: confirmationBinding)

            LabeledContent(String(localized: "WIP commit prefix")) {
                TextField(AppPreferences.fallbackWIPCommitPrefix, text: prefixBinding)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
            }

            Text(String(localized: "A repository can override this. When neither is set, homerun uses WIP."))
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker(String(localized: "Default sort order"), selection: sortBinding) {
                ForEach(RepositorySortOrder.allCases) { order in
                    Text(order.title).tag(order)
                }
            }
        }
    }

    // MARK: - Helpers

    private var confirmationBinding: Binding<Bool> {
        Binding(
            get: { settings.preferences.requiresSyncConfirmation },
            set: { value in settings.updatePreferences { $0.requiresSyncConfirmation = value } }
        )
    }

    private var prefixBinding: Binding<String> {
        Binding(
            get: { settings.preferences.wipCommitPrefix },
            set: { value in settings.updatePreferences { $0.wipCommitPrefix = value } }
        )
    }

    private var sortBinding: Binding<RepositorySortOrder> {
        Binding(
            get: { settings.preferences.repositorySortOrder },
            set: { value in settings.updatePreferences { $0.repositorySortOrder = value } }
        )
    }
}

#if DEBUG
#Preview("Repository settings") {
    Form {
        RepositorySettingsSection()
    }
    .formStyle(.grouped)
    .environment(\.settingsService, PreviewGraph.populated.settings)
    .frame(width: 560, height: 280)
}
#endif
