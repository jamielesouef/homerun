import Foundation

enum RepositoryPathEntryUseCase {
    static func url(from text: String, homeDirectory: URL) -> URL? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        while trimmed.count > 1, trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }

        guard trimmed.isEmpty == false else {
            return nil
        }

        guard trimmed.hasPrefix("~") == false else {
            return expanded(trimmed, homeDirectory: homeDirectory)
        }

        guard trimmed.hasPrefix("/") else {
            return nil
        }

        return URL(filePath: trimmed).standardizedFileURL
    }

    // MARK: - Helpers

    private static func expanded(_ path: String, homeDirectory: URL) -> URL? {
        var remainder = path.dropFirst()

        guard remainder.isEmpty || remainder.hasPrefix("/") else {
            return nil
        }

        if remainder.hasPrefix("/") {
            remainder = remainder.dropFirst()
        }

        guard remainder.isEmpty == false else {
            return homeDirectory.standardizedFileURL
        }

        return homeDirectory.appending(path: String(remainder)).standardizedFileURL
    }
}
