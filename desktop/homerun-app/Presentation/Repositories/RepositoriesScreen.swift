import SwiftUI

struct RepositoriesScreen: View {
    // MARK: - Constants

    private enum Constants {
        static let listMinimumWidth: CGFloat = 280
        static let listIdealWidth: CGFloat = 320
        static let listMaximumWidth: CGFloat = 380
    }

    // MARK: - Environment

    @Environment(\.repositoriesService) private var repositories
    @Environment(\.syncService) private var sync
    @Environment(\.filePanel) private var filePanel

    // MARK: - State

    @State private var selection: String?
    @State private var discovered: [DiscoveredRepository] = []
    @State private var pendingRemoval: RepositoryRemoval?

    // MARK: - View

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                list

                Divider()

                bottomBar
            }
            .frame(
                minWidth: Constants.listMinimumWidth,
                idealWidth: Constants.listIdealWidth,
                maxWidth: Constants.listMaximumWidth
            )

            Divider()

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

                Button(String(localized: "Add repository"), systemImage: "plus", action: addRepository)

                Button(String(localized: "Scan a folder"), systemImage: "magnifyingglass", action: scanFolder)

                Button(String(localized: "Sync selected"), systemImage: "arrow.triangle.2.circlepath") {
                    Task {
                        await sync.review(identifiers: selection.map { [$0] })
                    }
                }
            }
        }
        .searchable(text: searchBinding)
        .syncFlow()
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
        .dropDestination(for: URL.self) { urls, _ in
            addRepositories(at: urls)

            return true
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
                message: String(localized: "Choose a repository folder, scan a parent folder, or drag one in."),
                actionTitle: String(localized: "Add repository"),
                action: addRepository
            )
        case .loaded:
            loadedList
        }
    }

    private var loadedList: some View {
        List(repositories.visibleRepositories, selection: $selection) { repository in
            RepositoryRowView(repository: repository)
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

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
            Button(String(localized: "Add repository"), systemImage: "plus", action: addRepository)
                .buttonStyle(.borderless)

            if let message = repositories.lastMaintenanceMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.small)
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

    private func addRepository() {
        guard let url = filePanel.chooseFolder(message: String(localized: "Choose a git repository to track")) else {
            return
        }

        Task {
            _ = await repositories.addRepository(at: url)
        }
    }

    private func scanFolder() {
        guard let url = filePanel.chooseFolder(
            message: String(localized: "Choose a folder to scan for git repositories")
        ) else {
            return
        }

        Task {
            discovered = await repositories.scanFolder(url)
        }
    }

    private func addRepositories(at urls: [URL]) {
        guard urls.isEmpty == false else {
            return
        }

        Task {
            for url in urls {
                _ = await repositories.addRepository(at: url)
            }
        }
    }

    private func perform(_ removal: RepositoryRemoval) async {
        if selection == removal.identifier {
            selection = nil
        }

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
