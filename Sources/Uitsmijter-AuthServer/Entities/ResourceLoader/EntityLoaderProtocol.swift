import Foundation

// MARK: - Entity Loader Protocol

/// A protocol for loading entities from different sources.
///
/// Entity loaders are responsible for loading tenant and client configurations
/// from various sources such as:
/// - File system (YAML files)
/// - Kubernetes Custom Resource Definitions (CRDs)
/// - Other storage backends
///
/// Implementations of this protocol should:
/// 1. Load entities during initialization
/// 2. Watch for changes and notify via the handler
/// 3. Clean up resources on shutdown
///
/// ## Topics
///
/// ### Lifecycle
/// - ``init(handler:)``
/// - ``start()``
/// - ``shutdown()``
///
/// - SeeAlso: ``EntityLoaderProtocolFunctions``
@MainActor
protocol EntityLoaderProtocol {
    /// Initializes the entity loader with a callback handler.
    ///
    /// The loader should perform initial loading of entities during initialization
    /// but should not start watching for changes until ``start()`` is called.
    ///
    /// - Parameter handler: The callback interface for adding/removing entities.
    ///   May be `nil` if the loader is used in a read-only context.
    /// - Throws: ``EntityLoaderError`` if initialization fails
    init(handler: EntityLoaderProtocolFunctions?) throws

    /// Starts watching for entity changes.
    ///
    /// After calling this method, the loader should actively monitor its source
    /// for changes and notify the handler when entities are added, modified, or removed.
    ///
    /// - Throws: ``EntityLoaderError`` if the watch operation cannot be started
    func start() throws

    /// Stops watching and releases resources.
    ///
    /// This method should be called when shutting down the application to ensure
    /// proper cleanup of file monitors, network connections, or other resources.
    ///
    /// - Note: This method is `nonisolated` to allow cleanup from any context
    nonisolated func shutdown()
}

// MARK: - Entity Loader Functions

/// Callback interface for manipulating entities in the global storage.
///
/// This protocol defines the operations that an ``EntityLoaderProtocol`` implementation
/// can perform on the entity storage. Implementations receive a reference to this
/// protocol to add or remove entities as they are discovered or changed.
///
/// ## Topics
///
/// ### Entity Management
/// - ``addEntity(entity:)``
/// - ``removeEntity(entity:)``
@MainActor
protocol EntityLoaderProtocolFunctions {
    /// The storage instance used by this entity loader.
    var storage: EntityStorage { get }

    /// Adds a new entity to the global storage.
    ///
    /// This method is called by entity loaders when they discover a new tenant
    /// or client configuration, or when an existing entity has been modified.
    ///
    /// - Parameter entity: The entity to add (must be ``Tenant`` or ``UitsmijterClient``)
    /// - Returns: `true` if the entity was added successfully, `false` otherwise
    @discardableResult func addEntity(entity: Entity) -> Bool

    /// Removes an entity from the global storage.
    ///
    /// This method is called by entity loaders when a tenant or client configuration
    /// is deleted from the source.
    ///
    /// - Parameter entity: The entity to remove (must be ``Tenant`` or ``UitsmijterClient``)
    func removeEntity(entity: Entity)
}
