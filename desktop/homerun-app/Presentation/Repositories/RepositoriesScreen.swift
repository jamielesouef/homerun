import SwiftUI
import UniformTypeIdentifiers

struct RepositoriesScreen: View {
    // MARK: - Constants

    private enum Constants {
        static let listWidth: CGFloat = 320
    }

    // MARK: - Environment

    @Environment(\.repositoriesService) private var repositories
    @Environment(\.syncService) private var sync

    // MARK: - State

    @State private var selection: String?
    @State private var isImportingFolder = false
    @State private var isScanningFolder = false
    @State private var discovered: [DiscoveredRepository] = []
    @State private var pendingRemoval: RepositoryRemoval?

    // MARK: - View

    var body: some View {
        HSplitView {
            list
                .frame(minWidth: Constants.listWidth, idealWidth: Constants.listWidth)

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            await repositories.start()
        }
        .toolbar {
            ToolbarItemGroup {
                Picker(String(localized: "Filter"), selection: filterBinding) {
                    ForEach(RepositoryStatusFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)

                Picker(String(localized: "Sort"), selection: sortBinding) {
                    ForEach(RepositorySortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                }
                .pickerStyle(.menu)

                Button(String(localized: "Add repository"), systemImage: "plus") {
                    isImportingFolder = true
                }

                Button(String(localized: "Scan a folder"), systemImage: "magnifyingglass") {
                    isScanningFolder = true
                }

                Button(String(localized: "Sync selected"), systemImage: "arrow.triangle.2.circlepath") {
                    Task {
                        await sync.review(identifiers: selection.map { [$0] })
                    }
                }
            }
        }
        .searchable(text: searchBinding)
        .syncFlow()
        .fileImporter(isPresented: $isImportingFolder, allowedContentTypes: [.folder]) { result in
            handleImport(result, isScan: false)
        }
        .fileImporter(isPresented: $isScanningFolder, allowedContentTypes: [.folder]) { result in
            handleImport(result, isScan: true)
        }
        .sheet(isPresented: discoveredBinding) {
            DiscoveredRepositoriesSheet(discovered: discovered) { chosen in
                discovered = []

                Task {
                    await repositories.add(chosen)
                }
            } cancel: {
                discovered = []
            }
        }
        .alert(item: $pendingRemoval) { removal in
            Alert(
                title: Text(removal.title),
                message: Text(removal.explanation),
                primaryButton: .destructive(Text(String(localized: "Remove"))) {
                    Task {
                        await perform(removal)
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    // MARK: - List

    @ViewBuilder
    private var list: some View {
        switch repositories.loadState {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let error):
            EmptyStateView(
                symbolName: "exclamationmark.icloud",
                title: String(localized: "The shared workspace could not be read"),
                message: String(describing: error),
                actionTitle: String(localized: "Try again"),
                action: { Task { await repositories.refresh() } }
            )
        case .empty:
            EmptyStateView(
                symbolName: "folder.badge.plus",
                title: String(localized: "No repositories tracked"),
                message: String(localized: "Add a folder, scan a parent folder, or drag a repository in."),
                actionTitle: String(localized: "Add repository"),
                action: { isImportingFolder = true }
            )
        case .loaded:
            loadedList
        }
    }

    private var loadedList: some View {
        List(repositories.visibleRepositories, selection: $selection) { repository in
            RepositoryRowView(repository: repository)
                .tag(repository.id)
                .contextMenu {
                    Button(String(localized: "Sync")) {
                        Task {
                            await sync.review(identifiers: [repository.id])
                        }
                    }

                    Divider()

                    Button(String(localized: "Remove this Mac's path"), role: .destructive) {
                        pendingRemoval = RepositoryRemoval(identifier: repository.id, scope: .local)
                    }

                    Button(String(localized: "Remove from the shared workspace"), role: .destructive) {
                        pendingRemoval = RepositoryRemoval(identifier: repository.id, scope: .shared)
                    }
                }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if let selection, let repository = repositories.repository(identifier: selection) {
            RepositoryDetailView(repository: repository)
        } else {
            EmptyStateView(
                symbolName: "sidebar.right",
                title: String(localized: "Nothing selected"),
                message: String(localized: "Pick a repository to see its changes, branches and recent activity.")
            )
        }
    }

    // MARK: - Helpers

    private var filterBinding: Binding<RepositoryStatusFilter> {
        Binding(get: { repositories.filter }, set: { repositories.filter = $0 })
    }

    private var sortBinding: Binding<RepositorySortOrder> {
        Binding(get: { repositories.sortOrder }, set: { repositories.sortOrder = $0 })
    }

    private var searchBinding: Binding<String> {
        Binding(get: { repositories.searchText }, set: { repositories.searchText = $0 })
    }

    private var discoveredBinding: Binding<Bool> {
        Binding(
            get: { discovered.isEmpty == false },
            set: { isPresented in
                guard isPresented == false else {
                    return
                }

                discovered = []
            }
        )
    }

    private func handleImport(_ result: Result<URL, any Error>, isScan: Bool) {
        guard case .success(let url) = result else {
            return
        }

        Task {
            guard isScan else {
                _ = await repositories.addRepository(at: url)
                return
            }

            discovered = await repositories.scanFolder(url)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard providers.isEmpty == false else {
            return false
        }

        for provider in providers {
            _ = provider.loadTransferable(type: URL.self) { result in
                guard case .success(let url) = result else {
                    return
                }

                Task { @MainActor in
                    _ = await repositories.addRepository(at: url)
                }
            }
        }

        return true
    }

    private func perform(_ removal: RepositoryRemoval) async {
        switch removal.scope {
        case .local:
            await repositories.removeLocalPathMapping(identifier: removal.identifier)
        case .shared:
            await repositories.removeFromSharedWorkspace(identifier: removal.identifier)
        }
    }
}

#if DEBUG
#Preview("Populated") {
    RepositoriesScreen()
        .environment(\.repositoriesService, PreviewGraph.populated.repositories)
        .environment(\.syncService, PreviewGraph.populated.sync)
        .environment(\.accountsService, PreviewGraph.populated.accounts)
        .frame(width: 960, height: 620)
}

#Preview("Empty") {
    RepositoriesScreen()
        .environment(\.repositoriesService, PreviewGraph.empty.repositories)
        .environment(\.syncService, PreviewGraph.empty.sync)
        .environment(\.accountsService, PreviewGraph.empty.accounts)
        .frame(width: 960, height: 620)
}

#Preview("Long names") {
    RepositoriesScreen()
        .environment(\.repositoriesService, PreviewGraph.longNames.repositories)
        .environment(\.syncService, PreviewGraph.longNames.sync)
        .environment(\.accountsService, PreviewGraph.longNames.accounts)
        .frame(width: 960, height: 620)
}
#endif
