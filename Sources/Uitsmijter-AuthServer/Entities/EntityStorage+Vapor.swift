import Vapor

struct EntityStorageKey: StorageKey {
    typealias Value = EntityStorage
}

extension Application {
    /// Access the EntityStorage instance for this application
    ///
    /// Each Application instance gets its own EntityStorage, ensuring test isolation
    /// and proper dependency injection. In production, there's typically only one
    /// Application instance, so this effectively provides a single storage instance.
    ///
    /// In tests, each test creates its own Application, thus getting its own isolated
    /// EntityStorage instance, preventing race conditions when tests run in parallel.
    ///
    @MainActor var entityStorage: EntityStorage {
        get {
            // Get existing instance or create new one
            if let existing = storage[EntityStorageKey.self] {
                return existing
            }
            let new = EntityStorage()
            storage[EntityStorageKey.self] = new
            return new
        }
        set {
            storage[EntityStorageKey.self] = newValue
        }
    }
}
