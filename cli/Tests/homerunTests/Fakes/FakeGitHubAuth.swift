//
//  FakeGitHubAuth.swift
//  homerun
//
//  Created by Jamie Le Souëf on 10/09/2026.
//

@testable import homerun

// Tests drive this on one thread; the lock-free `@unchecked Sendable` is deliberate.
final class FakeGitHubAuth: GitHubAuth, @unchecked Sendable {
    private(set) var active: String?
    private let all: [String]
    private(set) var switches: [String] = []

    init(active: String?, all: [String]) {
        self.active = active
        self.all = all
    }

    var isAvailable: Bool { !all.isEmpty }

    func activeAccount() -> String? { active }

    func accounts() -> [String] {
        all.sorted { $0 == active && $1 != active }
    }

    func switchTo(account: String) throws {
        switches.append(account)
        active = account
    }
}
