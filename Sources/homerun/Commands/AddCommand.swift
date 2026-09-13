//
//  AddCommand.swift
//  homerun
//
//  Created by Jamie Le Souëf on 13/09/2026.
//

import ArgumentParser
import Foundation

struct AddCommand: ParsableCommand, HomerunCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add a repo to the config."
    )

    @Argument(help: "Path to the repo. \".\" means the current folder.")
    var path: String

    @Flag(name: [.customShort("r"), .long], help: "Walk the directory tree, add every git repo found, purge any tracked repo whose path no longer exists, and drop any duplicate entries.")
    var recursive = false

    @Option(help: "Push even when the branch is main or master. Re-adding a tracked repo keeps its existing value unless this is passed.")
    var main: Bool?

    @Option(name: [.customLong("wip-name")], help: "Prefix for the WIP commit message. Defaults to the config default, or \"WIP\".")
    var wipName: String?

    func run() throws {
        let code = try perform(git: ProcessGitClient(), store: JSONConfigStore(), confirmer: ReadLineConfirmer(), stdinIsTTY: false)
        if code != 0 { throw ExitCode(code) }
    }

    func perform(
        git: any GitClient, store: any ConfigStore, confirmer: any Confirmer,
        auth: (any GitHubAuth)?, stdinIsTTY: Bool, showProgress: Bool
    ) throws -> Int32 {
        try Add(path: path, recursive: recursive, main: main, wipName: wipName).run(git: git, store: store)
    }
}
