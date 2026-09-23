import SwiftUI
import UniformTypeIdentifiers

struct CleanerSettingsSection: View {
    // MARK: - Environment

    @Environment(\.settingsService) private var settings
    @Environment(\.cleanerService) private var cleaner

    // MARK: - State

    @State private var isChoosingPath = false

    // MARK: - View

    var body: some View {
        Section(String(localized: "Cleaner")) {
            Toggle(String(localized: "Include the default Derived Data location"), isOn: defaultLocationBinding)

            ForEach(CleanupCategory.allCases) { category in
                Toggle(String(localized: "Show \(category.title) in the review"), isOn: categoryBinding(category))
            }

            LabeledContent(String(localized: "Extra Derived Data paths")) {
                Button(String(localized: "Add…")) {
                    isChoosingPath = true
                }
            }

            ForEach(settings.localSettings.additionalDerivedDataPaths, id: \.self) { path in
                HStack {
                    Text(path)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button(String(localized: "Remove"), systemImage: "minus.circle") {
                        settings.updateLocalSettings { local in
                            local.additionalDerivedDataPaths.removeAll { $0 == path }
                        }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                }
            }
        }
        .fileImporter(isPresented: $isChoosingPath, allowedContentTypes: [.folder]) { result in
            guard case .success(let url) = result else {
                return
            }

            settings.updateLocalSettings { local in
                let path = url.path(percentEncoded: false)

                guard local.additionalDerivedDataPaths.contains(path) == false else {
                    return
                }

                local.additionalDerivedDataPaths.append(path)
            }
        }
    }

    // MARK: - Helpers

    private var defaultLocationBinding: Binding<Bool> {
        Binding(
            get: { settings.localSettings.includesDefaultDerivedData },
            set: { value in settings.updateLocalSettings { $0.includesDefaultDerivedData = value } }
        )
    }

    private func categoryBinding(_ category: CleanupCategory) -> Binding<Bool> {
        Binding(
            get: { cleaner.categories.contains(category) },
            set: { cleaner.setCategory(category, isEnabled: $0) }
        )
    }
}

#if DEBUG
#Preview("Cleaner settings") {
    Form {
        CleanerSettingsSection()
    }
    .formStyle(.grouped)
    .environment(\.settingsService, PreviewGraph.populated.settings)
    .environment(\.cleanerService, PreviewGraph.populated.cleaner)
    .frame(width: 620, height: 360)
}
#endif
