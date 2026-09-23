import Foundation

struct RepositoryRemoval: Identifiable {
    let identifier: String
    let scope: ConfigurationScope

    var id: String {
        "\(scope.rawValue):\(identifier)"
    }

    var title: String {
        switch scope {
        case .local:
            String(localized: "Remove this Mac's path?")
        case .shared:
            String(localized: "Remove from the shared workspace?")
        }
    }

    var explanation: String {
        switch scope {
        case .local:
            String(localized: "homerun will forget where this repository lives on this Mac. The shared workspace entry stays, and no files are deleted.")
        case .shared:
            String(localized: "homerun will remove this repository from the workspace on every Mac. No files are deleted.")
        }
    }
}
