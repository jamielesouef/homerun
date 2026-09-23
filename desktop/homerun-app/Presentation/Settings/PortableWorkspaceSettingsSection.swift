import SwiftUI
import UniformTypeIdentifiers

struct PortableWorkspaceSettingsSection: View {
    // MARK: - Environment

    @Environment(\.settingsService) private var settings
    @Environment(\.workspaceService) private var workspace
    @Environment(\.repositoriesService) private var repositories

    // MARK: - State

    @State private var isChoosingManifest = false
    @State private var isChoosingRoot = false
    @State private var isExportingManifest = false
    @State private var manifestName = "Workspace"

    // MARK: - View

    var body: some View {
        Section(String(localized: "Portable workspace")) {
            LabeledContent(String(localized: "This Mac's workspace root")) {
                HStack {
                    Text(settings.localSettings.workspaceRootPath ?? String(localized: "Not set"))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Button(String(localized: "Choose…")) {
                        isChoosingRoot = true
                    }
                }
            }

            LabeledContent(String(localized: "Manifest")) {
                HStack {
                    Text(settings.localSettings.manifestPath ?? String(localized: "None selected"))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Button(String(localized: "Load…")) {
                        isChoosingManifest = true
                    }

                    Button(String(localized: "Write…")) {
                        isExportingManifest = true
                    }
                }
            }

            preview
            relativePaths
        }
        .fileImporter(isPresented: $isChoosingRoot, allowedContentTypes: [.folder]) { result in
            guard case .success(let url) = result else {
                return
            }

            workspace.setWorkspaceRoot(url)
        }
        .fileImporter(isPresented: $isChoosingManifest, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else {
                return
            }

            Task {
                await workspace.loadManifest(at: url)
            }
        }
        .fileExporter(
            isPresented: $isExportingManifest,
            document: WorkspaceManifestDocument(),
            contentType: .json,
            defaultFilename: "homerun-workspace"
        ) { result in
            guard case .success(let url) = result else {
                return
            }

            Task {
                await workspace.exportManifest(named: manifestName, to: url)
            }
        }
    }

    // MARK: - Preview

    @ViewBuilder
    private var preview: some View {
        switch workspace.loadState {
        case .idle:
            Text(String(localized: "Load a manifest to preview what this Mac would clone."))
                .font(.caption)
                .foregroundStyle(.secondary)
        case .loading:
            ProgressView()
                .controlSize(.small)
        case .error(let error):
            Label(error.message, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        case .loaded(let manifest, let plan):
            loadedPreview(manifest, plan: plan)
        }
    }

    private func loadedPreview(_ manifest: WorkspaceManifest, plan: WorkspacePlan) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
            Text(String(localized: "\(manifest.name), version \(manifest.version): \(plan.cloneCount) to clone, \(plan.updateCount) already here."))
                .font(.caption)

            ForEach(plan.entries) { entry in
                Text("\(entry.name) — \(entry.action.summary)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Button(String(localized: "Apply to the shared workspace")) {
                Task {
                    await workspace.applyManifest()
                }
            }

            if let message = workspace.lastAppliedMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Relative paths

    @ViewBuilder
    private var relativePaths: some View {
        if repositories.repositories.isEmpty == false {
            DisclosureGroup(String(localized: "Preferred relative paths")) {
                ForEach(repositories.repositories) { repository in
                    LabeledContent(repository.name) {
                        TextField(
                            repository.name,
                            text: relativePathBinding(for: repository)
                        )
                        .textFieldStyle(.roundedBorder)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func relativePathBinding(for repository: TrackedRepository) -> Binding<String> {
        Binding(
            get: { repository.shared.preferredRelativePath },
            set: { value in
                Task {
                    await workspace.setPreferredRelativePath(value, for: repository.id)
                }
            }
        )
    }
}

#if DEBUG
#Preview("Portable workspace") {
    Form {
        PortableWorkspaceSettingsSection()
    }
    .formStyle(.grouped)
    .environment(\.settingsService, PreviewGraph.populated.settings)
    .environment(\.workspaceService, PreviewGraph.populated.workspace)
    .environment(\.repositoriesService, PreviewGraph.populated.repositories)
    .frame(width: 620, height: 480)
}

#Preview("Nothing configured") {
    Form {
        PortableWorkspaceSettingsSection()
    }
    .formStyle(.grouped)
    .environment(\.settingsService, PreviewGraph.empty.settings)
    .environment(\.workspaceService, PreviewGraph.empty.workspace)
    .environment(\.repositoriesService, PreviewGraph.empty.repositories)
    .frame(width: 620, height: 480)
}
#endif
