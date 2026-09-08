//  Confirmer.swift
//  homerun
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

protocol Confirmer: Sendable {
    func confirm(prompt: String) -> Bool
}
