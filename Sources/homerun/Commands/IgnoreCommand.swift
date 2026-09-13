//
//  IgnoreCommand.swift
//  homerun
//
//  Created by Jamie Le Souëf on 13/09/2026.
//

import ArgumentParser

struct IgnoreCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ignore",
        abstract: "Manage the folders skipped during \"add --recursive\".",
        subcommands: [Add.self, Remove.self, List.self]
    )

    struct Add: ParsableCommand, HomerunCommand {
        static let configuration = CommandConfiguration(
            commandName: "add",
            abstract: "Skip a folder during \"add --recursive\". \".\" means the current folder."
        )

        @Argument(help: "One or more folder names or paths.")
        var names: [String] = []

        func validate() throws {
            guard !names.isEmpty else {
                throw ValidationError("ignore add needs at least one name or path.")
            }
        }

        func run() throws {
            let code = try perform(git: ProcessGitClient(), store: JSONConfigStore(), confirmer: ReadLineConfirmer(), stdinIsTTY: false)
            if code != 0 { throw ExitCode(code) }
        }

        func perform(
            git: any GitClient, store: any ConfigStore, confirmer: any Confirmer,
            auth: (any GitHubAuth)?, stdinIsTTY: Bool, showProgress: Bool
        ) throws -> Int32 {
            try Ignore.add(names, store: store)
        }
    }

    struct Remove: ParsableCommand, HomerunCommand {
        static let configuration = CommandConfiguration(
            commandName: "rm",
            abstract: "Stop skipping a folder during \"add --recursive\".",
            aliases: ["remove"]
        )

        @Argument(help: "One or more folder names or paths.")
        var names: [String] = []

        func validate() throws {
            guard !names.isEmpty else {
                throw ValidationError("ignore rm needs at least one name or path.")
            }
        }

        func run() throws {
            let code = try perform(git: ProcessGitClient(), store: JSONConfigStore(), confirmer: ReadLineConfirmer(), stdinIsTTY: false)
            if code != 0 { throw ExitCode(code) }
        }

        func perform(
            git: any GitClient, store: any ConfigStore, confirmer: any Confirmer,
            auth: (any GitHubAuth)?, stdinIsTTY: Bool, showProgress: Bool
        ) throws -> Int32 {
            try Ignore.remove(names, store: store)
        }
    }

    struct List: ParsableCommand, HomerunCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "Show every ignored folder."
        )

        func run() throws {
            let code = try perform(git: ProcessGitClient(), store: JSONConfigStore(), confirmer: ReadLineConfirmer(), stdinIsTTY: false)
            if code != 0 { throw ExitCode(code) }
        }

        func perform(
            git: any GitClient, store: any ConfigStore, confirmer: any Confirmer,
            auth: (any GitHubAuth)?, stdinIsTTY: Bool, showProgress: Bool
        ) throws -> Int32 {
            try Ignore.list(store: store)
        }
    }
}
