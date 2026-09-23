import Foundation
@testable import homerun_app

actor StubPushFallback: PushFallbackPerforming {
    // MARK: - Configuration

    var result: AccountFallbackResult = .exhausted([])

    // MARK: - Recording

    private(set) var contexts: [PushAttemptContext] = []

    // MARK: - Init

    init(result: AccountFallbackResult = .exhausted([])) {
        self.result = result
    }

    // MARK: - PushFallbackPerforming

    func retryPush(_ context: PushAttemptContext) async -> AccountFallbackResult {
        contexts.append(context)

        return result
    }
}
