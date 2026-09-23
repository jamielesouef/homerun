import Foundation
import Testing
@testable import homerun_app

@Suite("RepositoryPathEntryUseCase", .tags(.domain))
struct RepositoryPathEntryUseCaseTests {
    // MARK: - Private

    private let home = URL(filePath: "/Users/jamie")

    // MARK: - Tests

    @Test("accepts an absolute path")
    func acceptsAbsolutePath() {
        #expect(RepositoryPathEntryUseCase.url(from: "  /dev/app  ", homeDirectory: home) == URL(filePath: "/dev/app"))
    }

    @Test("expands a path written from the home directory")
    func expandsTilde() {
        #expect(RepositoryPathEntryUseCase.url(from: "~/Developer/app", homeDirectory: home)
            == URL(filePath: "/Users/jamie/Developer/app"))
    }

    @Test("treats a bare tilde as the home directory")
    func acceptsBareTilde() {
        #expect(RepositoryPathEntryUseCase.url(from: "~", homeDirectory: home) == URL(filePath: "/Users/jamie"))
    }

    @Test("rejects anything that is not a path", arguments: ["", "   ", "app", "~user/app"])
    func rejectsNonPaths(text: String) {
        #expect(RepositoryPathEntryUseCase.url(from: text, homeDirectory: home) == nil)
    }

    @Test("standardises a path with redundant components")
    func standardisesPath() {
        #expect(RepositoryPathEntryUseCase.url(from: "/dev/./app/", homeDirectory: home) == URL(filePath: "/dev/app"))
    }
}
