import Vapor

struct EntityLoaderKey: StorageKey {
    typealias Value = EntityLoader
}

extension Application {
    /// Access the EntityLoader instance for this application
    ///
    /// The EntityLoader manages all entity loading sources (files, Kubernetes CRDs) and their lifecycle.
    /// It's important to properly shut down the EntityLoader to stop file watchers and clean up resources.
    ///
    /// In tests, each Application instance gets its own EntityLoader, ensuring test isolation.
    /// When the application shuts down, call `entityLoader?.shutdown()` to properly clean up resources.
    ///
    @MainActor public var entityLoader: EntityLoader? {
        get {
            storage[EntityLoaderKey.self]
        }
        set {
            storage[EntityLoaderKey.self] = newValue
        }
    }
}
