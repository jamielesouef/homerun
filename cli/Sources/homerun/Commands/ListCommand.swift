//
//  ListCommand.swift
//  homerun
//
//  Created by Jamie Le Souëf on 13/09/2026.
//

import ArgumentParser

struct ListCommand: ParsableCommand, HomerunCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List the repos currently tracked in the config."
    )

    func run() throws {
        let code = try perform(git: ProcessGitClient(), store: JSONConfigStore(), confirmer: ReadLineConfirmer(), stdinIsTTY: false)
        if code != 0 { throw ExitCode(code) }
    }

    func perform(
        git: any GitClient, store: any ConfigStore, confirmer: any Confirmer,
        auth: (any GitHubAuth)?, stdinIsTTY: Bool, showProgress: Bool
    ) throws -> Int32 {
        try ListRepos().run(store: store)
    }
}
