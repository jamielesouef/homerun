//
//  RemoveCommand.swift
//  homerun
//
//  Created by Jamie Le Souëf on 13/09/2026.
//

import ArgumentParser

struct RemoveCommand: ParsableCommand, HomerunCommand {
    static let configuration = CommandConfiguration(
        commandName: "rm",
        abstract: "Remove a repo from the config.",
        aliases: ["remove"]
    )

    @Argument(help: "The repo's id, its path, or \".\" for the current folder.")
    var target: String

    func run() throws {
        let code = try perform(git: ProcessGitClient(), store: JSONConfigStore(), confirmer: ReadLineConfirmer(), stdinIsTTY: false)
        if code != 0 { throw ExitCode(code) }
    }

    func perform(
        git: any GitClient, store: any ConfigStore, confirmer: any Confirmer,
        auth: (any GitHubAuth)?, stdinIsTTY: Bool, showProgress: Bool
    ) throws -> Int32 {
        try Remove(target: target).run(store: store)
    }
}
