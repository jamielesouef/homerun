//
//  GitError.swift
//  homerun
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

struct GitError: Error, Equatable {
    // The last line of git's stderr; this is what the red row prints.
    var message: String

    static func describe(_ error: any Error) -> String {
        (error as? GitError)?.message ?? String(describing: error)
    }

    // A push rejected because the active credentials lack access — the case a
    // `gh auth switch` to another account can recover from. Deliberately narrow:
    // a non-fast-forward or merge-conflict rejection is not an auth problem.
    var isAuthFailure: Bool {
        let lowered = message.lowercased()
        let markers = [
            "permission denied",
            "could not read from remote",
            "authentication failed",
            "403",
            "remote: repository not found",
            "fatal: repository not found",
            "access denied",
        ]
        return markers.contains { lowered.contains($0) }
    }
}
