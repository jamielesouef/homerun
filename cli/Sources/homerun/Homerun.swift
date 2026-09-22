//
//  Homerun.swift
//  homerun
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

import ArgumentParser

@main
struct Homerun: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "WIP-commit and push every tracked repo so work is never stranded on one machine.",
        subcommands: [
            SyncCommand.self, AddCommand.self, RemoveCommand.self, ListCommand.self,
            CleanCommand.self, IgnoreCommand.self, ConfigCommand.self,
        ],
        defaultSubcommand: SyncCommand.self
    )
}
