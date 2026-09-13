//
//  Settings.swift
//  homerun
//
//  Created by Jamie Le Souëf on 13/09/2026.
//

// Config-wide settings: `homerun config main` / `homerun config wip-name`.
enum Settings {
    // Retargets the repo the user is standing in.
    static func setMain(_ value: Bool, store: any ConfigStore) throws -> Int32 {
        var config = try store.load() ?? Config()
        let path = Paths.resolved(".")
        guard config.setMain(value, path: path) else {
            print(Style.paint("❌ \(path) is not in the config. Add it with \"homerun add\".", "31"))
            return 1
        }
        try store.save(config)
        print(Style.paint("🔀 main set to \(value) for \(path)", "32"))
        return 0
    }

    static func setDefaultWipName(_ name: String, store: any ConfigStore) throws -> Int32 {
        var config = try store.load() ?? Config()
        config.defaultWipName = name
        try store.save(config)
        print(Style.paint("⚙️  Default commit prefix set to \"\(name)\"", "32"))
        return 0
    }
}
