//
//  RepoStatus.swift
//  homerun
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

enum RepoStatus: Equatable, Sendable {
    case clean
    // `ahead` is nil when there is no upstream to count against.
    case needsPush(changed: Int, ahead: Int?, upstream: String?)
    case skipped(reason: String)
    case failed(String)

    var needsPush: Bool {
        if case .needsPush = self { return true }
        return false
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}
