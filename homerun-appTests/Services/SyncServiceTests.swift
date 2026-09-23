import Foundation
import Testing
@testable import homerun_app

@Suite("SyncService", .tags(.service))
struct SyncServiceTests {
    // MARK: - Review

    @Test("shows the plan for confirmation before anything is committed or pushed")
    @MainActor
    func showsPlanForConfirmation() async {
        let harness = ServiceHarness()
        await harness.addRepository(
            "a",
            name: "app",
            snapshot: RepositoryFixtures.snapshot(branch: "feature/login", ahead: 1)
        )
        await harness.repositories.start()
        let service = harness.makeSync()

        await service.review(identifiers: nil)

        #expect(service.reviewPlan?.actionableSteps.count == 1)
        #expect(await harness.syncEngine.requests.isEmpty)
    }

    @Test("syncs straight away when confirmation is switched off")
    @MainActor
    func skipsConfirmationWhenDisabled() async {
        let harness = ServiceHarness()
        await harness.addRepository(
            "a",
            name: "app",
            snapshot: RepositoryFixtures.snapshot(branch: "feature/login", ahead: 1)
        )
        await harness.repositories.start()
        harness.settings.updatePreferences { $0.requiresSyncConfirmation = false }
        let service = harness.makeSync()

        await service.review(identifiers: nil)

        #expect(await harness.syncEngine.requests.count == 1)
        #expect(service.phase == .finished(SyncSummary(outcomes: [
            RepositorySyncOutcome(
                identifier: "a",
                result: .succeeded(commit: "newhead", branch: "feature/login"),
                finishedAt: harness.clock.now()
            )
        ])))
    }

    @Test("syncs only the repositories that were selected")
    @MainActor
    func syncsSelectionOnly() async {
        let harness = ServiceHarness()
        await harness.addRepository(
            "a",
            name: "a",
            snapshot: RepositoryFixtures.snapshot(branch: "feature/a", ahead: 1)
        )
        await harness.addRepository(
            "b",
            name: "b",
            snapshot: RepositoryFixtures.snapshot(branch: "feature/b", ahead: 1)
        )
        await harness.repositories.start()
        let service = harness.makeSync()

        await service.review(identifiers: ["b"])
        await service.run()

        #expect(await harness.syncEngine.requests.map(\.identifier) == ["b"])
    }

    @Test("adds an untracked file to the plan only once the review selects it")
    @MainActor
    func addsUntrackedOnSelection() async {
        let harness = ServiceHarness()
        await harness.addRepository(
            "a",
            name: "app",
            snapshot: RepositoryFixtures.snapshot(branch: "feature/login", untracked: ["Notes.md"])
        )
        await harness.repositories.start()
        let service = harness.makeSync()
        await service.review(identifiers: nil)

        #expect(service.reviewPlan?.actionableSteps.isEmpty == true)

        service.toggleUntracked("Notes.md", for: "a")

        #expect(service.isUntrackedSelected("Notes.md", for: "a"))
        #expect(service.reviewPlan?.actionableSteps.first?.includedUntrackedPaths == ["Notes.md"])
    }

    // MARK: - Running

    @Test("builds a request carrying the repository's own WIP prefix")
    @MainActor
    func usesRepositoryPrefix() async {
        let harness = ServiceHarness()
        harness.settings.updatePreferences { $0.wipCommitPrefix = "PARKED" }
        var shared = RepositoryFixtures.shared("a", name: "app")
        shared.wipCommitPrefixOverride = "SCRATCH"
        await harness.addRepository(
            "a",
            name: "app",
            snapshot: RepositoryFixtures.snapshot(
                branch: "feature/login",
                tracked: [GitFileChange(path: "A", status: .modified)]
            ),
            shared: shared
        )
        await harness.repositories.start()
        let service = harness.makeSync()

        await service.review(identifiers: nil)
        await service.run()

        #expect(await harness.syncEngine.requests.first?.commitMessage == "SCRATCH 2025-09-23 04:00:00")
    }

    @Test("falls back to the app-wide WIP prefix when the repository has none")
    @MainActor
    func usesAppWidePrefix() async {
        let harness = ServiceHarness()
        harness.settings.updatePreferences { $0.wipCommitPrefix = "PARKED" }
        await harness.addRepository(
            "a",
            name: "app",
            snapshot: RepositoryFixtures.snapshot(
                branch: "feature/login",
                tracked: [GitFileChange(path: "A", status: .modified)]
            )
        )
        await harness.repositories.start()
        let service = harness.makeSync()

        await service.review(identifiers: nil)
        await service.run()

        #expect(await harness.syncEngine.requests.first?.commitMessage.hasPrefix("PARKED") == true)
    }

    @Test("passes the fallback and access-check settings through to the engine")
    @MainActor
    func passesAccountSettings() async {
        let harness = ServiceHarness()
        harness.settings.updatePreferences {
            $0.accountFallbackEnabled = false
            $0.accountAccessChecksEnabled = true
        }
        await harness.addRepository(
            "a",
            name: "app",
            snapshot: RepositoryFixtures.snapshot(branch: "feature/login", ahead: 1)
        )
        await harness.repositories.start()
        let service = harness.makeSync()

        await service.review(identifiers: nil)
        await service.run()

        let request = await harness.syncEngine.requests.first
        #expect(request?.fallbackEnabled == false)
        #expect(request?.checksAccountAccess == true)
    }

    @Test("reports a summary of what succeeded and what failed")
    @MainActor
    func reportsSummary() async {
        let harness = ServiceHarness()
        await harness.addRepository(
            "a",
            name: "a",
            snapshot: RepositoryFixtures.snapshot(branch: "feature/a", ahead: 1)
        )
        await harness.addRepository(
            "b",
            name: "b",
            snapshot: RepositoryFixtures.snapshot(branch: "feature/b", ahead: 1)
        )
        await harness.repositories.start()
        await harness.syncEngine.setResult(.failed(.diverged), for: "b")
        let service = harness.makeSync()

        await service.review(identifiers: nil)
        await service.run()

        guard case let .finished(summary) = service.phase else {
            Issue.record("expected a finished summary")
            return
        }

        #expect(summary.succeededCount == 1)
        #expect(summary.failedCount == 1)
        #expect(summary.failures.first?.identifier == "b")
    }

    @Test("carries a blocked repository into the summary as a failure without calling the engine")
    @MainActor
    func reportsBlockedWithoutRunning() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot(branch: "main", ahead: 1))
        await harness.repositories.start()
        let service = harness.makeSync()

        await service.review(identifiers: nil)
        await service.run()

        guard case let .finished(summary) = service.phase else {
            Issue.record("expected a finished summary")
            return
        }

        #expect(summary.failures.first?.result == .failed(.branchNotAllowed("main")))
        #expect(await harness.syncEngine.requests.isEmpty)
    }

    @Test("writes the outcomes back so the repository list reflects them")
    @MainActor
    func writesOutcomesBack() async {
        let harness = ServiceHarness()
        await harness.addRepository(
            "a",
            name: "app",
            snapshot: RepositoryFixtures.snapshot(branch: "feature/login", ahead: 1)
        )
        await harness.repositories.start()
        let service = harness.makeSync()

        await service.review(identifiers: nil)
        await service.run()

        #expect(harness.sharedStore.repositories.first?.handoff?.branch == "feature/login")
    }

    @Test("leaving the review runs nothing")
    @MainActor
    func cancellingReviewRunsNothing() async {
        let harness = ServiceHarness()
        await harness.addRepository(
            "a",
            name: "app",
            snapshot: RepositoryFixtures.snapshot(branch: "feature/login", ahead: 1)
        )
        await harness.repositories.start()
        let service = harness.makeSync()
        await service.review(identifiers: nil)

        service.cancelReview()
        await service.run()

        #expect(service.phase == .idle)
        #expect(await harness.syncEngine.requests.isEmpty)
    }
}
