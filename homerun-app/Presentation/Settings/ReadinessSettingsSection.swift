import SwiftUI

struct ReadinessSettingsSection: View {
    // MARK: - Environment

    @Environment(\.repositoriesService) private var repositories

    // MARK: - State

    @State private var selection: String?

    // MARK: - View

    var body: some View {
        Section(String(localized: "Readiness checks")) {
            Text(String(localized: "These travel in the manifest so another Mac knows what a project needs. Values are never copied, only names."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker(String(localized: "Repository"), selection: $selection) {
                Text(String(localized: "Choose a repository")).tag(String?.none)

                ForEach(repositories.repositories) { repository in
                    Text(repository.name).tag(String?.some(repository.id))
                }
            }

            if let selection, let repository = repositories.repository(identifier: selection) {
                editor(for: repository)
            }
        }
    }

    // MARK: - Editor

    private func editor(for repository: TrackedRepository) -> some View {
        Group {
            LabeledContent(String(localized: "Setup instructions")) {
                TextField("README.md", text: optionalBinding(repository, \.setupInstructionsPath))
                    .textFieldStyle(.roundedBorder)
            }

            LabeledContent(String(localized: "Required environment variables")) {
                TextField("API_HOST, API_TOKEN", text: listBinding(repository, \.requiredEnvironmentVariableNames))
                    .textFieldStyle(.roundedBorder)
            }

            LabeledContent(String(localized: "Expected configuration templates")) {
                TextField(".env.example", text: listBinding(repository, \.expectedConfigurationTemplates))
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    // MARK: - Helpers

    private func optionalBinding(
        _ repository: TrackedRepository,
        _ keyPath: WritableKeyPath<WorkspaceRepository, String?>
    ) -> Binding<String> {
        Binding(
            get: { repository.shared[keyPath: keyPath] ?? "" },
            set: { value in
                var shared = repository.shared
                shared[keyPath: keyPath] = value.isEmpty ? nil : value
                repositories.update(shared)
            }
        )
    }

    private func listBinding(
        _ repository: TrackedRepository,
        _ keyPath: WritableKeyPath<WorkspaceRepository, [String]>
    ) -> Binding<String> {
        Binding(
            get: { repository.shared[keyPath: keyPath].joined(separator: ", ") },
            set: { value in
                var shared = repository.shared
                shared[keyPath: keyPath] = value
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.isEmpty == false }
                repositories.update(shared)
            }
        )
    }
}

#if DEBUG
#Preview("Readiness settings") {
    Form {
        ReadinessSettingsSection()
    }
    .formStyle(.grouped)
    .environment(\.repositoriesService, PreviewGraph.populated.repositories)
    .frame(width: 620, height: 320)
}
#endif
