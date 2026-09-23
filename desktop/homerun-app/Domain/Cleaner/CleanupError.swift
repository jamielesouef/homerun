import Foundation

enum CleanupError: Error, Equatable {
    case protectedLocation(String)
    case toolUnavailable
    case removalFailed(String)

    var message: String {
        switch self {
        case .protectedLocation(let path):
            String(localized: "homerun will not remove \(path) because it belongs to an Xcode installation.")
        case .toolUnavailable:
            String(localized: "The Xcode command line tools are not available.")
        case .removalFailed(let detail):
            detail
        }
    }
}
