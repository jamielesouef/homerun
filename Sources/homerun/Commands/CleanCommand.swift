//
//  CleanCommand.swift
//  homerun
//
//  Created by Jamie Le Souëf on 13/09/2026.
//

import ArgumentParser
import Foundation

struct CleanCommand: ParsableCommand, HomerunCommand {
    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Remove tracked repos that no longer exist on disk, or are tracked more than once."
    )

    @Flag(help: "Remove tracked repos whose path no longer exists on disk.")
    var missing = false

    @Flag(help: "Remove duplicate repos, keeping one entry per repo.")
    var dupes = false

    @Flag(help: "Remove every repo from the config.")
    var all = false

    @Flag(name: [.customShort("y"), .customLong("yes"), .customLong("yolo")], help: "Skip the confirmation prompt.")
    var yolo = false

    func validate() throws {
        if all, missing || dupes {
            throw ValidationError("--all cannot be combined with --missing or --dupes.")
        }
    }

    func run() throws {
        let code = try perform(git: ProcessGitClient(), store: JSONConfigStore(), confirmer: ReadLineConfirmer(), stdinIsTTY: isatty(STDIN_FILENO) != 0)
        if code != 0 { throw ExitCode(code) }
    }

    func perform(
        git: any GitClient, store: any ConfigStore, confirmer: any Confirmer,
        auth: (any GitHubAuth)?, stdinIsTTY: Bool, showProgress: Bool
    ) throws -> Int32 {
        try Clean(missing: missing, dupes: dupes, all: all, yolo: yolo)
            .run(git: git, store: store, confirmer: confirmer, stdinIsTTY: stdinIsTTY)
    }
}
