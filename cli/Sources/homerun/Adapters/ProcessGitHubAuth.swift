//
//  ProcessGitHubAuth.swift
//  homerun
//
//  Created by Jamie Le Souëf on 10/09/2026.
//

import Foundation

struct ProcessGitHubAuth: GitHubAuth {
    var isAvailable: Bool {
        !accounts().isEmpty
    }

    func activeAccount() -> String? {
        parse(statusOutput()).first { $0.active }?.name
    }

    func accounts() -> [String] {
        let parsed = parse(statusOutput())
        // Active account first so the retry loop leaves it for last.
        return parsed.sorted { $0.active && !$1.active }.map(\.name)
    }

    func switchTo(account: String) throws {
        _ = try run(["auth", "switch", "--hostname", "github.com", "--user", account])
    }

    private struct Account {
        var name: String
        var active: Bool
    }

    // `gh auth status` has no JSON mode, so the human-readable output is parsed.
    // Lines look like: "  ✓ Logged in to github.com account NAME (keyring)"
    // followed by "  - Active account: true".
    private func parse(_ output: String) -> [Account] {
        var accounts: [Account] = []
        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let range = trimmed.range(of: "account "), trimmed.contains("Logged in to") {
                let rest = trimmed[range.upperBound...]
                let name = rest.split(separator: " ").first.map(String.init) ?? ""
                if !name.isEmpty { accounts.append(Account(name: name, active: false)) }
            } else if trimmed.hasPrefix("- Active account: true"), !accounts.isEmpty {
                accounts[accounts.count - 1].active = true
            }
        }
        return accounts
    }

    private func statusOutput() -> String {
        (try? run(["auth", "status"])) ?? ""
    }

    private func run(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh"] + arguments
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
        } catch {
            // `gh` not on PATH: treat as "no accounts", never crash the run.
            throw GitError(message: "gh not available")
        }
        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        let errors = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            // `gh auth status` combines its account listing on stderr in some versions.
            let combined = String(decoding: output, as: UTF8.self) + String(decoding: errors, as: UTF8.self)
            if arguments.first == "auth", arguments.dropFirst().first == "status", !combined.isEmpty {
                return combined
            }
            let lastLine = String(decoding: errors, as: UTF8.self)
                .split(separator: "\n").last.map(String.init)
            throw GitError(message: lastLine ?? "gh exited \(process.terminationStatus)")
        }
        return String(decoding: output, as: UTF8.self) + String(decoding: errors, as: UTF8.self)
    }
}
