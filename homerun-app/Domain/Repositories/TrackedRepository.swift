import Foundation

struct TrackedRepository: Equatable, Identifiable {
    let shared: WorkspaceRepository
    let localPath: URL?
    let snapshot: GitRepositorySnapshot?
    let lastSyncOutcome: RepositorySyncOutcome?
    let readError: GitError?
    let isLoadingSnapshot: Bool

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
        guard isCloned else {
            return .notCloned
        }
        guard isLoadingSnapshot == false else {
            return .loading
        }

        switch (readError, lastSyncOutcome?.didFail == true, snapshot) {
        case (_?, _, _):
            return .unreadable
        case (nil, true, _):
            return .failed
        case (nil, false, let snapshot?):
            return Self.status(for: snapshot)
        case (nil, false, nil):
            return .unreadable
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
        readError: GitError? = nil,
        isLoadingSnapshot: Bool = false
    ) {
        self.shared = shared
        self.localPath = localPath
        self.snapshot = snapshot
        self.lastSyncOutcome = lastSyncOutcome
        self.readError = readError
        self.isLoadingSnapshot = isLoadingSnapshot
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
