//  ReadLineConfirmer.swift
//  homerun
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

import Foundation

struct ReadLineConfirmer: Confirmer {
    func confirm() -> Bool {
        print("Continue? [y/N] ", terminator: "")
        // No newline means no automatic flush, so the prompt would never appear.
        fflush(stdout)
        let answer = readLine()?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
        return answer == "y" || answer == "yes"
    }
}
