//
//  Row.swift
//  homerun
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

// A rendered output line. `text` is always plain; colour is applied at the edge by `Style`.
struct Row: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case pushed
        case clean
        case pending
        case failed
    }

    var text: String
    var kind: Kind
}

extension Row {
    private struct Cell {
        var symbol: String
        var name: String
        var detail: String
        var kind: Kind
        var action: String? = nil
    }

    static func render(plans: [RepoPlan]) -> [Row] {
        align(plans.map(cell))
    }

    static func render(results: [RepoResult]) -> [Row] {
        align(results.map(cell))
    }

    static func summary(plans: [RepoPlan]) -> String {
        let statuses = plans.map(\.status)
        return joinCounts([
            (statuses.filter(\.needsPush).count, "to push"),
            (statuses.filter { if case .skipped = $0 { true } else { false } }.count, "skipped"),
            (statuses.filter { $0 == .clean }.count, "clean"),
            (statuses.filter(\.isFailed).count, "failed"),
        ])
    }

    static func summary(results: [RepoResult]) -> String {
        let outcomes = results.map(\.outcome)
        return joinCounts([
            (outcomes.filter { if case .pushed = $0 { true } else { false } }.count, "pushed"),
            (outcomes.filter { $0 == .skipped }.count, "skipped"),
            (outcomes.filter { if case .failed = $0 { true } else { false } }.count, "failed"),
        ])
    }

    private static func cell(_ plan: RepoPlan) -> Cell {
        let name = plan.entry.name
        switch plan.status {
        case .clean:
            return Cell(symbol: "✓", name: name, detail: "clean", kind: .clean)
        case .needsPush(let changed, let ahead, let upstream):
            var parts: [String] = []
            if changed > 0 { parts.append("\(changed) changed") }
            if let ahead, ahead > 0 { parts.append("\(ahead) ahead") }
            if upstream == nil { parts.append("no upstream") }
            let target = upstream ?? "origin/\(plan.branch ?? "?") (-u)"
            return Cell(symbol: "↑", name: name, detail: parts.joined(separator: ", "), kind: .pending, action: "push → \(target)")
        case .skipped(let reason):
            return Cell(symbol: "⊘", name: name, detail: reason, kind: .pending, action: "skip")
        case .failed(let reason):
            return Cell(symbol: "✗", name: name, detail: reason, kind: .failed)
        }
    }

    private static func cell(_ result: RepoResult) -> Cell {
        let name = result.plan.entry.name
        switch result.outcome {
        case .pushed(let target):
            return Cell(symbol: "✓", name: name, detail: "pushed → \(target)", kind: .pushed)
        case .skipped:
            return Cell(symbol: "⊘", name: name, detail: "skipped", kind: .pending)
        case .failed(let reason):
            return Cell(symbol: "✗", name: name, detail: reason, kind: .failed)
        }
    }

    private static func joinCounts(_ counts: [(Int, String)]) -> String {
        counts.filter { $0.0 > 0 }.map { "\($0.0) \($0.1)" }.joined(separator: " · ")
    }

    // Column widths come from the longest name and longest detail in the set.
    private static func align(_ cells: [Cell]) -> [Row] {
        let nameWidth = cells.map(\.name.count).max() ?? 0
        let detailWidth = cells.map(\.detail.count).max() ?? 0
        return cells.map { cell in
            var text = "  \(cell.symbol)  \(pad(cell.name, to: nameWidth))  \(pad(cell.detail, to: detailWidth))"
            if let action = cell.action { text += "  \(action)" }
            while text.hasSuffix(" ") { text.removeLast() }
            return Row(text: text, kind: cell.kind)
        }
    }

    private static func pad(_ string: String, to width: Int) -> String {
        string + String(repeating: " ", count: max(0, width - string.count))
    }
}
