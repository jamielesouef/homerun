import Foundation

enum WorkspaceIdentifier {
    static func make(remoteURL: String?, folderName: String) -> String {
        guard let normalised = normalisedRemote(remoteURL) else {
            return "local:\(folderName.lowercased())"
        }

        return "remote:\(normalised)"
    }

    static func normalisedRemote(_ remoteURL: String?) -> String? {
        guard var value = remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines), value.isEmpty == false else {
            return nil
        }

        value = value.lowercased()

        if value.hasSuffix(".git") {
            value.removeLast(4)
        }

        if value.hasSuffix("/") {
            value.removeLast()
        }

        for prefix in ["https://", "http://", "ssh://", "git://"] where value.hasPrefix(prefix) {
            value.removeFirst(prefix.count)
        }

        if value.hasPrefix("git@") {
            value.removeFirst("git@".count)
            value = value.replacingOccurrences(of: ":", with: "/")
        }

        return value
    }
}
