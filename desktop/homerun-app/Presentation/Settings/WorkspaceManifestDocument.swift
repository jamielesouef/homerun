import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceManifestDocument: FileDocument {
    static let readableContentTypes = [UTType.json]

    init() {}

    init(configuration: ReadConfiguration) throws {}

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data())
    }
}
