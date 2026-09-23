import SwiftUI

struct AddRepositoryByPathField: View {
    // MARK: - Environment

    @Environment(\.repositoriesService) private var repositories

    // MARK: - State

    @State private var text = ""

    // MARK: - Inputs

    let homeDirectory: URL

    // MARK: - View

    var body: some View {
        HStack(spacing: AppSpacing.small) {
            TextField(String(localized: "Path to a repository"), text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit(add)

            Button(String(localized: "Add"), action: add)
                .disabled(resolvedURL == nil)
        }
    }

    // MARK: - Helpers

    private var resolvedURL: URL? {
        RepositoryPathEntryUseCase.url(from: text, homeDirectory: homeDirectory)
    }

    private func add() {
        guard let url = resolvedURL else {
            return
        }

        text = ""

        Task {
            _ = await repositories.addRepository(at: url)
        }
    }
}

#if DEBUG
#Preview("Empty") {
    AddRepositoryByPathField(homeDirectory: URL(filePath: "/Users/preview"))
        .environment(\.repositoriesService, PreviewGraph.populated.repositories)
        .padding()
        .frame(width: 420)
}
#endif
