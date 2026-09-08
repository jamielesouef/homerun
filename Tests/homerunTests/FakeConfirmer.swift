//  FakeConfirmer.swift
//  homerun
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

@testable import homerun

struct FakeConfirmer: Confirmer {
    var answer: Bool

    func confirm(prompt: String) -> Bool { answer }
}
