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
}
