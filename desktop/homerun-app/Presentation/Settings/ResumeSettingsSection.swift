import SwiftUI
import UniformTypeIdentifiers

struct ResumeSettingsSection: View {
    // MARK: - Environment

    @Environment(\.settingsService) private var settings

    // MARK: - State

    @State private var isChoosingApplication = false

    // MARK: - View

    var body: some View {
        Section(String(localized: "Resume")) {
            Toggle(String(localized: "Preselect safe fast-forward updates"), isOn: fastForwardBinding)

            Toggle(String(localized: "Offer to open a project once it is ready"), isOn: offerToOpenBinding)

            LabeledContent(String(localized: "Open projects with")) {
                HStack {
                    Text(applicationName)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Button(String(localized: "Choose…")) {
                        isChoosingApplication = true
                    }

                    if settings.localSettings.preferredOpenApplicationPath != nil {
                        Button(String(localized: "Clear")) {
                            settings.updateLocalSettings { $0.preferredOpenApplicationPath = nil }
                        }
                    }
                }
            }
        }
        .fileImporter(isPresented: $isChoosingApplication, allowedContentTypes: [.application]) { result in
            guard case .success(let url) = result else {
                return
            }

            settings.updateLocalSettings { $0.preferredOpenApplicationPath = url.path(percentEncoded: false) }
        }
    }

    // MARK: - Helpers

    private var applicationName: String {
        guard let path = settings.localSettings.preferredOpenApplicationPath else {
            return String(localized: "The system default")
        }

        return URL(filePath: path).lastPathComponent
    }

    private var fastForwardBinding: Binding<Bool> {
        Binding(
            get: { settings.preferences.preselectsSafeFastForward },
            set: { value in settings.updatePreferences { $0.preselectsSafeFastForward = value } }
        )
    }

    private var offerToOpenBinding: Binding<Bool> {
        Binding(
            get: { settings.preferences.offersToOpenProjectAfterResume },
            set: { value in settings.updatePreferences { $0.offersToOpenProjectAfterResume = value } }
        )
    }
}

#if DEBUG
#Preview("Resume settings") {
    Form {
        ResumeSettingsSection()
    }
    .formStyle(.grouped)
    .environment(\.settingsService, PreviewGraph.populated.settings)
    .frame(width: 560, height: 240)
}
#endif
