//
//  Paths.swift
//  homerun
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

import Foundation

enum Paths {
    static func resolved(_ path: String) -> String {
        path == "." ? FileManager.default.currentDirectoryPath : path
    }
}
