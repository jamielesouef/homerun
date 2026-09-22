//
//  ConfigCommand.swift
//  homerun
//
//  Created by Jamie Le Souëf on 13/09/2026.
//

import ArgumentParser

struct ConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "View or change config-wide settings.",
        subcommands: [Main.self, WipName.self]
    )

    struct Main: ParsableCommand, HomerunCommand {
        static let configuration = CommandConfiguration(
            commandName: "main",
            abstract: "Push even when the branch is main or master, for the repo in the current folder."
        )

        @Argument(help: "true or false.")
        var value: Bool

        func run() throws {
            let code = try perform(git: ProcessGitClient(), store: JSONConfigStore(), confirmer: ReadLineConfirmer(), stdinIsTTY: false)
            if code != 0 { throw ExitCode(code) }
        }

        func perform(
            git: any GitClient, store: any ConfigStore, confirmer: any Confirmer,
            auth: (any GitHubAuth)?, stdinIsTTY: Bool, showProgress: Bool
        ) throws -> Int32 {
            try Settings.setMain(value, store: store)
        }
    }

    struct WipName: ParsableCommand, HomerunCommand {
        static let configuration = CommandConfiguration(
            commandName: "wip-name",
            abstract: "Set the config-wide default WIP commit prefix."
        )

        @Argument(help: "The commit message prefix.")
        var prefix: String

        func run() throws {
            let code = try perform(git: ProcessGitClient(), store: JSONConfigStore(), confirmer: ReadLineConfirmer(), stdinIsTTY: false)
            if code != 0 { throw ExitCode(code) }
        }

        func perform(
            git: any GitClient, store: any ConfigStore, confirmer: any Confirmer,
            auth: (any GitHubAuth)?, stdinIsTTY: Bool, showProgress: Bool
        ) throws -> Int32 {
            try Settings.setDefaultWipName(prefix, store: store)
        }
    }
}
