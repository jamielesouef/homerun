//
//  HomerunCommand.swift
//  homerun
//
//  Created by Jamie Le Souëf on 13/09/2026.
//

import ArgumentParser

// Every leaf subcommand conforms to this so tests can drive it with fake
// dependencies, exactly as `Homerun.perform` used to be driven directly.
protocol HomerunCommand: ParsableCommand {
    func perform(
        git: any GitClient, store: any ConfigStore, confirmer: any Confirmer,
        auth: (any GitHubAuth)?, stdinIsTTY: Bool, showProgress: Bool
    ) throws -> Int32
}

extension HomerunCommand {
    // `auth` defaults to nil and `showProgress` to false so most tests need not pass them.
    func perform(
        git: any GitClient, store: any ConfigStore, confirmer: any Confirmer,
        stdinIsTTY: Bool, showProgress: Bool = false
    ) throws -> Int32 {
        try perform(git: git, store: store, confirmer: confirmer, auth: nil, stdinIsTTY: stdinIsTTY, showProgress: showProgress)
    }
}
