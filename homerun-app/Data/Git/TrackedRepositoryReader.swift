import Foundation

struct TrackedRepositoryReader: @unchecked Sendable {
    // MARK: - Private

    private let gitClient: any GitClienting
    private let fileManager: FileManager
    private let worktreeReader: TrackedWorktreeReader

    // MARK: - Init

    init(gitClient: any GitClienting, fileManager: FileManager) {
        self.gitClient = gitClient
        self.fileManager = fileManager
        worktreeReader = TrackedWorktreeReader(gitClient: gitClient)
    }

    // MARK: - Reading

    func read(
        _ repository: WorkspaceRepository,
        path: String?,
        outcomes: [String: RepositorySyncOutcome]
    ) async -> TrackedRepository {
        let lastSyncOutcome = outcomes[repository.identifier]

        guard let path, fileManager.fileExists(atPath: path) else {
            return TrackedRepository(shared: repository, lastSyncOutcome: lastSyncOutcome)
        }

        let directory = URL(filePath: path)

        do {
            let snapshot = try await gitClient.snapshot(at: directory)
            let worktrees = await worktreeReader.worktrees(of: repository, at: directory, outcomes: outcomes)

            let main = TrackedRepository(
                shared: repository,
                localPath: directory,
                snapshot: snapshot,
                lastSyncOutcome: lastSyncOutcome
            )

            return WorktreeUseCase.linking(main, to: worktrees)
        } catch {
            return TrackedRepository(
                shared: repository,
                localPath: directory,
                lastSyncOutcome: lastSyncOutcome,
                readError: error
            )
        }
    }
}
