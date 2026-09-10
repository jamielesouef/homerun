//
//  ProcessGitClient.swift
//  homerun
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

import Foundation

struct ProcessGitClient: GitClient {
    func isRepo(at path: String) -> Bool {
        (try? run(["rev-parse", "--is-inside-work-tree"], at: path)) == "true"
    }

    func currentBranch(at path: String) throws -> String? {
        let branch = try run(["branch", "--show-current"], at: path)
        return branch.isEmpty ? nil : branch
    }

    func porcelainStatus(at path: String) throws -> [String] {
        try run(["status", "--porcelain"], at: path).split(separator: "\n").map(String.init)
    }

    func upstream(at path: String) throws -> String? {
        // git exits non-zero when no upstream is configured; that is the nil case.
        try? run(["rev-parse", "--abbrev-ref", "@{u}"], at: path)
    }

    func aheadCount(at path: String) throws -> Int {
        Int(try run(["rev-list", "--count", "@{u}..HEAD"], at: path)) ?? 0
    }

    func stageAll(at path: String) throws {
        _ = try run(["add", "-A"], at: path)
    }

    func commit(at path: String, message: String) throws {
        _ = try run(["commit", "-m", message], at: path)
    }

    func push(at path: String, branch: String, setUpstream: Bool) throws {
        _ = try run(setUpstream ? ["push", "-u", "origin", branch] : ["push"], at: path)
    }

    private func run(_ arguments: [String], at path: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-C", path] + arguments
        // Setting `environment` replaces the whole env, so copy PATH et al. before adding.
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        process.environment = environment
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        // Drain both pipes before waiting, or a chatty git deadlocks on a full buffer.
        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        let errors = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let lastLine = String(decoding: errors, as: UTF8.self)
                .split(separator: "\n").last.map(String.init)
            throw GitError(message: lastLine ?? "git exited \(process.terminationStatus)")
        }
        return String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
