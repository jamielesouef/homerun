import Foundation

struct TrackedRepository: Equatable, Identifiable {
    let shared: WorkspaceRepository
    let localPath: URL?
    let snapshot: GitRepositorySnapshot?
    let lastSyncOutcome: RepositorySyncOutcome?
    let readError: GitError?

    var id: String {
        shared.identifier
    }

    var name: String {
        shared.name
    }

    var isCloned: Bool {
        localPath != nil
    }

    var status: RepositoryStatus {
        switch (isCloned, readError, lastSyncOutcome?.didFail == true, snapshot) {
        case (false, _, _, _):
            .notCloned
        case (_, _?, _, _):
            .unreadable
        case (_, nil, true, _):
            .failed
        case (_, nil, false, let snapshot?):
            Self.status(for: snapshot)
        case (_, nil, false, nil):
            .unreadable
        }
    }

    var hasLocalOnlyWork: Bool {
        guard let snapshot else {
            return false
        }

        return snapshot.isDirty
            || snapshot.aheadCount > 0
            || snapshot.otherBranchesNeedingPush.isEmpty == false
    }

    init(
        shared: WorkspaceRepository,
        localPath: URL? = nil,
        snapshot: GitRepositorySnapshot? = nil,
        lastSyncOutcome: RepositorySyncOutcome? = nil,
        readError: GitError? = nil
    ) {
        self.shared = shared
        self.localPath = localPath
        self.snapshot = snapshot
        self.lastSyncOutcome = lastSyncOutcome
        self.readError = readError
    }

    // MARK: - Helpers

    private static func status(for snapshot: GitRepositorySnapshot) -> RepositoryStatus {
        switch (snapshot.isDiverged, snapshot.isDirty, snapshot.aheadCount > 0, snapshot.behindCount > 0) {
        case (true, _, _, _):
            .diverged
        case (false, true, _, _):
            .dirty
        case (false, false, true, _):
            .ahead
        case (false, false, false, true):
            .behind
        case (false, false, false, false):
            .clean
        }
    }
}
