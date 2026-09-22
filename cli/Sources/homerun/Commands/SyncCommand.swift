//
//  SyncCommand.swift
//  homerun
//
//  Created by Jamie Le Souëf on 13/09/2026.
//

import ArgumentParser
import Foundation

// The default subcommand: `homerun` with no subcommand name runs this.
struct SyncCommand: AsyncParsableCommand, HomerunCommand {
    static let configuration = CommandConfiguration(
        commandName: "sync",
        abstract: "Scan every tracked repo, show the plan, and push what needs it."
    )

    @Flag(name: [.customShort("d"), .long], help: "Show the plan and exit. Never prompts, never writes.")
    var dryRun = false

    @Flag(name: [.customShort("y"), .customLong("yes"), .customLong("yolo")], help: "Skip the prompt and push immediately.")
    var yolo = false

    @Option(name: [.customShort("p"), .long], help: "Limit the scan to this configured repo. Repeatable.")
    var repo: [String] = []

    func validate() throws {
        if yolo && dryRun {
            throw ValidationError("--yes and --dry-run cannot be combined.")
        }
    }

    func run() async throws {
        let code = try perform(
            git: ProcessGitClient(), store: JSONConfigStore(), confirmer: ReadLineConfirmer(),
            auth: ProcessGitHubAuth(), stdinIsTTY: isatty(STDIN_FILENO) != 0, showProgress: isatty(STDOUT_FILENO) != 0)
        if code != 0 { throw ExitCode(code) }
    }

    func perform(
        git: any GitClient, store: any ConfigStore, confirmer: any Confirmer,
        auth: (any GitHubAuth)?, stdinIsTTY: Bool, showProgress: Bool
    ) throws -> Int32 {
        try Sync(repo: repo, dryRun: dryRun, yolo: yolo)
            .run(git: git, store: store, confirmer: confirmer, auth: auth, stdinIsTTY: stdinIsTTY, showProgress: showProgress)
    }
}
