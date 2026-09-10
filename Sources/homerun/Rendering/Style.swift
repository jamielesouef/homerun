//
//  Style.swift
//  homerun
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

import Foundation

enum Style {
    // The colour gate is on stdout; the TTY-for-prompting check in Homerun is on stdin.
    static let colourEnabled: Bool = isatty(STDOUT_FILENO) != 0
        && ProcessInfo.processInfo.environment["NO_COLOR"] == nil
        && ProcessInfo.processInfo.environment["TERM"] != "dumb"

    static func apply(_ row: Row, colour: Bool = colourEnabled) -> String {
        guard colour else { return row.text }
        let code = switch row.kind {
        case .pushed: "32"
        case .clean: "2"
        case .pending: "33"
        case .failed: "31"
        }
        return "\u{1b}[\(code)m\(row.text)\u{1b}[0m"
    }

    // For one-off status lines outside the plan/result tables — errors, confirmations,
    // the --list card. `code` is a raw ANSI SGR code: "32" green, "31" red, "33" yellow,
    // "2" dim, "1;36" bold cyan, and so on.
    static func paint(_ text: String, _ code: String, colour: Bool = colourEnabled) -> String {
        guard colour else { return text }
        return "\u{1b}[\(code)m\(text)\u{1b}[0m"
    }
}
