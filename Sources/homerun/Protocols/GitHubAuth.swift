//
//  GitHubAuth.swift
//  homerun
//
//  Created by Jamie Le Souëf on 10/09/2026.
//

// Wraps the `gh` CLI's account switching so the push-retry path is testable
// without a real `gh` install or a live GitHub login.
protocol GitHubAuth: Sendable {
    // True when `gh` is installed and has at least one authenticated account.
    var isAvailable: Bool { get }
    // The account `gh` currently treats as active, or nil if none/unavailable.
    func activeAccount() -> String?
    // Every authenticated account, active first.
    func accounts() -> [String]
    // Point `gh` (and its git credential helper) at `account`.
    func switchTo(account: String) throws
}
