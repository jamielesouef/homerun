import Foundation
import SwiftData

enum ModelContainerFactory {
    static let schema = Schema([SharedRepositoryRecord.self, SharedPreferencesRecord.self])

    static func make(
        inMemory: Bool,
        cloudKitContainerIdentifier: String?
    ) throws(PersistenceError) -> ModelContainer {
        let cloudKitDatabase: ModelConfiguration.CloudKitDatabase

        switch cloudKitContainerIdentifier {
        case let identifier? where inMemory == false:
            cloudKitDatabase = .private(identifier)
        case .some,
             .none:
            cloudKitDatabase = .none
        }

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: cloudKitDatabase
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            return try makeLocalFallback(inMemory: inMemory, underlying: error)
        }
    }

    // MARK: - Helpers

    private static func makeLocalFallback(inMemory: Bool, underlying: any Error) throws(PersistenceError) -> ModelContainer {
        AppLog.error("Falling back to a local store: \(underlying.localizedDescription)")

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            throw .containerUnavailable(error.localizedDescription)
        }
    }
}
