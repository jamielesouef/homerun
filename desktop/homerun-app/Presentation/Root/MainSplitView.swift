import SwiftUI

struct MainSplitView: View {
    // MARK: - Constants

    private enum Constants {
        static let sidebarMinimum: CGFloat = 200
        static let sidebarIdeal: CGFloat = 220
        static let detailMinimum: CGFloat = 560
    }

    // MARK: - Environment

    @Environment(\.repositoriesService) private var repositories

    // MARK: - State

    @State private var section: AppSection = .today

    // MARK: - View

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(AppSection.allCases, selection: $section) { item in
                    NavigationLink(value: item) {
                        Label(item.title, systemImage: item.symbolName)
                    }
                }

                #if DEBUG
                Divider()

                DebugMenuView()
                #endif
            }
            .navigationSplitViewColumnWidth(min: Constants.sidebarMinimum, ideal: Constants.sidebarIdeal)
        } detail: {
            detail
                .frame(minWidth: Constants.detailMinimum)
                .navigationTitle(section.title)
        }
        .task {
            await repositories.start()
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch section {
        case .today:
            TodayScreen()
        case .repositories:
            RepositoriesScreen()
        case .gitHubAccounts:
            GitHubAccountsScreen()
        case .cleaner:
            CleanerScreen()
        case .settings:
            SettingsScreen()
        }
    }
}

#if DEBUG
#Preview("Populated") {
    MainSplitView()
        .environment(\.repositoriesService, PreviewGraph.populated.repositories)
        .environment(\.syncService, PreviewGraph.populated.sync)
        .environment(\.resumeService, PreviewGraph.populated.resume)
        .frame(width: 960, height: 640)
}

#Preview("Empty") {
    MainSplitView()
        .environment(\.repositoriesService, PreviewGraph.empty.repositories)
        .frame(width: 960, height: 640)
}
#endif
