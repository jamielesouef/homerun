import Testing
@testable import homerun_app

@Suite("WorkspaceIdentifier", .tags(.domain))
struct WorkspaceIdentifierTests {
    @Test("gives the same identifier to the same remote written different ways", arguments: [
        "git@github.com:Acme/App.git",
        "https://github.com/acme/app.git",
        "https://github.com/acme/app/",
        "ssh://github.com/acme/app"
    ])
    func matchesEquivalentRemotes(remote: String) {
        #expect(WorkspaceIdentifier.make(remoteURL: remote, folderName: "app") == "remote:github.com/acme/app")
    }

    @Test("falls back to the folder name when a repository has no remote")
    func fallsBackToFolderName() {
        #expect(WorkspaceIdentifier.make(remoteURL: nil, folderName: "Scratch") == "local:scratch")
        #expect(WorkspaceIdentifier.make(remoteURL: "  ", folderName: "Scratch") == "local:scratch")
    }

    @Test("separates two different remotes")
    func separatesDifferentRemotes() {
        let first = WorkspaceIdentifier.make(remoteURL: "git@github.com:acme/app.git", folderName: "app")
        let second = WorkspaceIdentifier.make(remoteURL: "git@github.com:acme/other.git", folderName: "app")

        #expect(first != second)
    }
}
