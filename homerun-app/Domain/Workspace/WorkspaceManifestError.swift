import Foundation

enum WorkspaceManifestError: Error, Equatable {
    case fileUnreadable(String)
    case malformed(String)
    case unsupportedVersion(Int)
    case writeFailed(String)

    var message: String {
        switch self {
        case .fileUnreadable(let path):
            String(localized: "The manifest at \(path) could not be read.")
        case .malformed(let detail):
            String(localized: "The manifest is not in a format homerun understands: \(detail)")
        case .unsupportedVersion(let version):
            String(localized: "This manifest is version \(version), which this build of homerun does not support.")
        case .writeFailed(let detail):
            String(localized: "The manifest could not be written: \(detail)")
        }
    }
}
