import Foundation

struct TrackedRepositoryReader: @unchecked Sendable {
    // MARK: - Private

    private let gitClient: any GitClienting
    private let fileManager: FileManager

    // MARK: - Init

    init(gitClient: any GitClienting, fileManager: FileManager) {
        self.gitClient = gitClient
        self.fileManager = fileManager
    }

    // MARK: - Reading

    func read(
        _ repository: WorkspaceRepository,
        path: String?,
        lastSyncOutcome: RepositorySyncOutcome?
    ) async -> TrackedRepository {
        guard let path, fileManager.fileExists(atPath: path) else {
            return TrackedRepository(shared: repository, lastSyncOutcome: lastSyncOutcome)
        }

        let directory = URL(filePath: path)

        do {
            let snapshot = try await gitClient.snapshot(at: directory)

            return TrackedRepository(
                shared: repository,
                localPath: directory,
                snapshot: snapshot,
                lastSyncOutcome: lastSyncOutcome
            )
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
