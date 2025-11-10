import Foundation
@preconcurrency import FileMonitor
import Logger
#if os(Linux)
import Glibc
#endif

@MainActor
class EntityFileLoaderTenantChangedHandler: @unchecked Sendable, FileDidChangeDelegate {
    typealias LoaderFunction = (URL) throws -> Tenant?

    var delegate: EntityLoaderProtocolFunctions?
    var loader: LoaderFunction?

    /// Gets called when a file changes
    ///
    /// - Parameter event: FileChange event
    nonisolated func fileDidChanged(event: FileChange) {
        Log.info("Detected tenant change \(event)")
        // FileChange from external FileMonitor package isn't Sendable, but this usage is safe
        let unsafeEvent = UnsafeTransfer(event)
        Task { @MainActor in
            eventHandler(event: unsafeEvent.wrappedValue, ofType: Tenant.self, delegate: delegate) { url in
                try loadEntity(from: url)
            }
        }
    }

    /// Load Tenant entity form a file url
    ///
    /// - Parameter file: URl of the tenant configuration file
    /// - Returns: A `Tenant`
    /// - Throws: An `EntityLoaderError` when file could not be loaded for some reasons
    private func loadEntity(from file: URL) throws -> Tenant {
        guard let loader else {
            Log.error("There is no loader defined for tenant events.")
            throw EntityLoaderError.noLoaderRegistered
        }

        // try to load the new entity
        guard let entity = try loader(file) else {
            Log.error("Cannot load tenant from \(file)")
            throw EntityLoaderError.canNotLoad(from: file)
        }
        if entity.ref == nil {
            Log.error("Unexpectedly the tenant  has no reference. Will be set to \(file.path)")
        }
        let entityRef: EntityResourceReference = entity.ref ?? .file(file)

        // normally this should never happen, because the file path is the reference path, but to be sure there
        // is nothing left - Refactoring: remove if otherwise secured
        if let delegate {
            let alreadyExistingTenant = Tenant.find(in: delegate.storage, ref: entityRef)
            if let alreadyExistingTenant { // if alreadyExistingTenant != nil
                Log.warning("Removing Tenant based on reference \(entityRef).")
                delegate.removeEntity(entity: alreadyExistingTenant)
            }
        }
        return entity
    }

}

@MainActor
class EntityFileLoaderClientChangedHandler: @unchecked Sendable, FileDidChangeDelegate {
    typealias LoaderFunction = (URL) throws -> UitsmijterClient?

    var delegate: EntityLoaderProtocolFunctions?
    var loader: LoaderFunction?

    nonisolated func fileDidChanged(event: FileChange) {
        Log.info("Detected client change \(event)")
        // FileChange from external FileMonitor package isn't Sendable, but this usage is safe
        let unsafeEvent = UnsafeTransfer(event)
        Task { @MainActor in
            eventHandler(event: unsafeEvent.wrappedValue, ofType: UitsmijterClient.self, delegate: delegate) { url in
                try loadEntity(from: url)
            }
        }
    }

    private func loadEntity(from file: URL) throws -> UitsmijterClient {
        guard let loader else {
            Log.error("There is no loader defined for client events.")
            throw EntityLoaderError.noLoaderRegistered
        }

        // try to load the new entity
        guard let entity = try loader(file) else {
            Log.error("Cannot load client from \(file)")
            throw EntityLoaderError.canNotLoad(from: file)
        }
        if entity.ref == nil {
            Log.error("Unexpectedly the client  has no reference. Will be set to \(file.path)")
        }
        let entityRef: EntityResourceReference = entity.ref ?? .file(file)

        // normally this should never happen, because the file path is the reference path, but to be sure there
        // is nothing left - Refactoring: remove if otherwise secured
        if let delegate {
            let alreadyExistingClient = UitsmijterClient.find(in: delegate.storage, ref: entityRef)
            if let alreadyExistingClient { // if alreadyExistingClient != nil
                Log.warning("Removing Client based on reference \(entityRef).")
                delegate.removeEntity(entity: alreadyExistingClient)
            }
        }
        return entity
    }
}

@MainActor
struct EntityFileLoader: EntityLoaderProtocol {
    var delegate: EntityLoaderProtocolFunctions?

    let clientFileMonitor: FileMonitor?
    let tenantFileMonitor: FileMonitor?

    init(handler: EntityLoaderProtocolFunctions?) throws {
        guard let tenantPath = URL(string: resourcePath)?
                .appendingPathComponent("Configurations")
                .appendingPathComponent("Tenants")
        else {
            throw ApplicationConfigError.directoryConfigError(
                "Cannot read Configurations/Tenants in \(resourcePath)"
            )
        }

        guard let clientPath = URL(string: resourcePath)?
                .appendingPathComponent("Configurations")
                .appendingPathComponent("Clients")
        else {
            throw ApplicationConfigError.directoryConfigError(
                "Cannot read Configurations/Clients in \(resourcePath)"
            )
        }

        // set delegate
        delegate = handler

        // register file monitor - gracefully handle inotify exhaustion in test environments
        // Skip file monitoring in test environments where it's disabled
        let monitors: (tenant: FileMonitor?, client: FileMonitor?)
        let enableMonitoring = ProcessInfo.processInfo.environment["DISABLE_FILE_MONITORING"] != "true"

        if enableMonitoring {
            do {
                let tenantChangedHandler = EntityFileLoaderTenantChangedHandler()
                tenantChangedHandler.delegate = delegate

                let clientChangedHandler = EntityFileLoaderClientChangedHandler()
                clientChangedHandler.delegate = delegate

                tenantChangedHandler.loader = { (url) throws -> Tenant? in
                    if let data = FileManager.default.contents(atPath: url.path) {
                        if let yamlContent = String(data: data, encoding: .utf8) {
                            return try Tenant(yaml: yamlContent, ref: .file(url))
                        }
                    }
                    return nil
                }

                clientChangedHandler.loader = { (url) throws -> UitsmijterClient? in
                    if let data = FileManager.default.contents(atPath: url.path) {
                        if let yamlContent = String(data: data, encoding: .utf8) {
                            return try Client(yaml: yamlContent, ref: .file(url))
                        }
                    }
                    return nil
                }

                let tMonitor = try FileMonitor(directory: tenantPath, delegate: tenantChangedHandler)
                let cMonitor = try FileMonitor(directory: clientPath, delegate: clientChangedHandler)
                monitors = (tMonitor, cMonitor)
                Log.debug("File monitoring enabled for entity configurations")
            } catch {
                Log.warning("File monitoring disabled: \(error.localizedDescription)")
                monitors = (nil, nil)
            }
        } else {
            Log.info("File monitoring disabled (inotify unavailable in test environment)")
            monitors = (nil, nil)
        }

        tenantFileMonitor = monitors.tenant
        clientFileMonitor = monitors.client

        try loadEntity(from: tenantPath).forEach { (tenant: UitsmijterTenant) in
            delegate?.addEntity(entity: tenant)
        }

        try loadEntity(from: clientPath).forEach { (client: UitsmijterClient) in
            delegate?.addEntity(entity: client)
        }
    }

    /// Starts file monitoring for tenant and client configuration files.
    ///
    /// Begins watching the configured directories for changes to YAML files.
    /// When files are added, modified, or deleted, the loader automatically
    /// updates the entity storage.
    ///
    /// - Throws: Errors from the underlying file monitor initialization
    func start() throws {
        try tenantFileMonitor?.start()
        try clientFileMonitor?.start()
    }

    /// Stops file monitoring and cleans up resources.
    ///
    /// Halts all file monitoring operations and releases associated resources.
    /// This should be called during application shutdown to ensure clean termination.
    func shutdown() {
        clientFileMonitor?.stop()
        tenantFileMonitor?.stop()
    }

    // MARK: - Private functions

    /// Check if inotify can be initialized (test for file monitoring availability)
    /// - Returns: true if file monitoring is available, false otherwise
    private static func canInitializeFileMonitor() -> Bool {
        #if os(Linux)
        // Try to initialize inotify to check if it's available
        let fileDescriptor = inotify_init1(Int32(IN_CLOEXEC))
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            return true
        }
        return false
        #else
        return true // FileMonitor works differently on macOS/BSD
        #endif
    }

    /// Load Config Resource from Filesystem
    ///
    /// - Parameters:
    ///   - configDirectory: URL from which the Entity should be loaded
    /// - Returns: An array of decoded entities of T.Type.
    /// - Throws: An error when entities can't be decoded.
    func loadEntity<T: Entity>(
        from configDirectory: URL
    ) throws -> [T] where T: Entity {
        let resourceFilePaths = try listYamls(in: configDirectory)
        Log.info("Found \(resourceFilePaths.count) resources in \(configDirectory)")
        return resourceFilePaths.compactMap { url in
            do {
                let yamlContent = try String(contentsOf: url, encoding: .utf8)
                return try T.init(yaml: yamlContent, ref: .file(url))
            } catch {
                let errorDesc = error.localizedDescription
                Log.error("Cannot read content or parse yaml from \(url.absoluteString): \(errorDesc) as \(T.self)")
            }
            return nil
        }
    }

    /// Return all yamls from a directory
    ///
    /// - Parameter directory: URL from which the YAMLS should be listed.
    /// - Returns: an array of URLs
    /// - Throws: em error if the FileManager can's list file from the directory
    func listYamls(in directory: URL) throws -> [URL] {
        let contentsOfDirectory = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return contentsOfDirectory.filter { directory in
            directory.pathExtension == "yaml" || directory.pathExtension == "yml"
        }
    }
}

// MARK: - Event handler used by Tenant and Client class.

fileprivate typealias EntityLoaderFunction = (URL) throws -> Entity

@MainActor
fileprivate func eventHandler(
    event: FileChange,
    ofType: EntityFindResourceReferenceProtocol.Type,
    delegate: EntityLoaderProtocolFunctions?,
    loader loadEntity: EntityLoaderFunction
) {
    switch event {
    case .changed(let file):
        // remove if there is a file reference to the file path
        if let delegate,
           let existingEntityOnFilePath = ofType.find(in: delegate.storage, ref: .file(file)) {
            delegate.removeEntity(entity: existingEntityOnFilePath)
        }
        do {
            // add the new entity
            delegate?.addEntity(entity: try loadEntity(file))
        } catch {
            Log.error("Changed file \(file.path) cannot handle entity, \(error.localizedDescription)")
        }
    case .added(let file):
        do {
            // add the new entity
            delegate?.addEntity(entity: try loadEntity(file))
        } catch {
            Log.error("Added file \(file.path) cannot handle entity, \(error.localizedDescription)")
        }
    case .deleted(let file):
        if let delegate,
           let entityToRemove = ofType.find(in: delegate.storage, ref: .file(file)) {
            delegate.removeEntity(entity: entityToRemove)
        } else {
            Log.error("Cannot remove \(type(of: ofType)) from file \(file.path), because the reference is unknown")
        }
    }
}
