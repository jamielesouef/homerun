import SwiftUI

struct GitHubAccountSettingsSection: View {
    // MARK: - Environment

    @Environment(\.settingsService) private var settings
    @Environment(\.accountsService) private var accounts

    // MARK: - View

    var body: some View {
        Section(String(localized: "GitHub accounts")) {
            Toggle(String(localized: "Retry a refused push with the other signed-in accounts"), isOn: fallbackBinding)

            Toggle(String(localized: "Check account access before syncing"), isOn: accessCheckBinding)

            Text(String(localized: "These only apply to repositories that push over HTTPS. An SSH remote uses your SSH key, which switching accounts does not change."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Helpers

    private var fallbackBinding: Binding<Bool> {
        Binding(
            get: { settings.preferences.accountFallbackEnabled },
            set: { accounts.setFallbackEnabled($0) }
        )
    }

    private var accessCheckBinding: Binding<Bool> {
        Binding(
            get: { settings.preferences.accountAccessChecksEnabled },
            set: { accounts.setAccessChecksEnabled($0) }
        )
    }
}

#if DEBUG
#Preview("Account settings") {
    Form {
        GitHubAccountSettingsSection()
    }
    .formStyle(.grouped)
    .environment(\.settingsService, PreviewGraph.populated.settings)
    .environment(\.accountsService, PreviewGraph.populated.accounts)
    .frame(width: 560, height: 220)
}
#endif
