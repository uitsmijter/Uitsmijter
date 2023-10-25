import Foundation
import Vapor
import FileMonitor

class EntityFileLoaderTenantChangedHandler: FileDidChangeDelegate {
    typealias LoaderFunction = (URL) throws -> Tenant?

    var delegate: EntityLoaderProtocolFunctions?
    var loader: LoaderFunction?

    /// Gets called when a file changes
    ///
    /// - Parameter event: FileChange event
    func fileDidChanged(event: FileChange) {
        Log.info("Detect a tenant change \(event)")
        eventHandler(event: event, ofType: Tenant.self, delegate: delegate) { url in
            try loadEntity(from: url)
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
            Log.error("Can not load tenant from \(file)")
            throw EntityLoaderError.canNotLoad(from: file)
        }
        if entity.ref == nil {
            Log.error("Unexpectedly the tenant  has no reference. Will be set to \(file.path)")
        }
        let entityRef: EntityResourceReference = entity.ref ?? .file(file)

        // normally this should never happen, because the file path is the reference path, but to be sure there
        // is nothing left - Refactoring: remove if otherwise secured
        let alreadyExistingTenant = Tenant.find(ref: entityRef)
        if let alreadyExistingTenant { // if alreadyExistingTenant != nil
            Log.warning("Removing a Tenant on behalf the reference \(entityRef).")
            delegate?.removeEntity(entity: alreadyExistingTenant)
        }
        return entity
    }

}

class EntityFileLoaderClientChangedHandler: FileDidChangeDelegate {
    typealias LoaderFunction = (URL) throws -> Client?

    var delegate: EntityLoaderProtocolFunctions?
    var loader: LoaderFunction?

    func fileDidChanged(event: FileChange) {
        Log.info("Detect a client change \(event)")
        eventHandler(event: event, ofType: Client.self, delegate: delegate) { url in
            try loadEntity(from: url)
        }
    }

    private func loadEntity(from file: URL) throws -> Client {
        guard let loader else {
            Log.error("There is no loader defined for client events.")
            throw EntityLoaderError.noLoaderRegistered
        }

        // try to load the new entity
        guard let entity = try loader(file) else {
            Log.error("Can not load client from \(file)")
            throw EntityLoaderError.canNotLoad(from: file)
        }
        if entity.ref == nil {
            Log.error("Unexpectedly the client  has no reference. Will be set to \(file.path)")
        }
        let entityRef: EntityResourceReference = entity.ref ?? .file(file)

        // normally this should never happen, because the file path is the reference path, but to be sure there
        // is nothing left - Refactoring: remove if otherwise secured
        let alreadyExistingClient = Client.find(ref: entityRef)
        if let alreadyExistingClient { // if alreadyExistingClient != nil
            Log.warning("Removing a Client on behalf the reference \(entityRef).")
            delegate?.removeEntity(entity: alreadyExistingClient)
        }
        return entity
    }
}

struct EntityFileLoader: EntityLoaderProtocol {
    var delegate: EntityLoaderProtocolFunctions?

    let clientFileMonitor: FileMonitor
    let tenantFileMonitor: FileMonitor

    init(handler: EntityLoaderProtocolFunctions?) throws {
        guard let tenantPath = URL(string: resourcePath)?
                .appendingPathComponent("Configurations")
                .appendingPathComponent("Tenants")
        else {
            throw ApplicationConfigError.directoryConfigError(
                    "Can not read Configurations/Tenants in \(resourcePath)"
            )
        }

        guard let clientPath = URL(string: resourcePath)?
                .appendingPathComponent("Configurations")
                .appendingPathComponent("Clients")
        else {
            throw ApplicationConfigError.directoryConfigError(
                    "Can not read Configurations/Clients in \(resourcePath)"
            )
        }

        // set delegate
        delegate = handler

        // register file monitor
        let tenantChangedHandler = EntityFileLoaderTenantChangedHandler()
        tenantChangedHandler.delegate = delegate

        let clientChangedHandler = EntityFileLoaderClientChangedHandler()
        clientChangedHandler.delegate = delegate

        tenantFileMonitor = try FileMonitor(directory: tenantPath, delegate: tenantChangedHandler)
        clientFileMonitor = try FileMonitor(directory: clientPath, delegate: clientChangedHandler)

        tenantChangedHandler.loader = { (url) throws -> Tenant? in
            if let data = FileManager.default.contents(atPath: url.path) {
                if let yamlContent = String(data: data, encoding: .utf8) {
                    return try Tenant(yaml: yamlContent, ref: .file(url))
                }
            }
            return nil
        }

        clientChangedHandler.loader = { (url) throws -> Client? in
            if let data = FileManager.default.contents(atPath: url.path) {
                if let yamlContent = String(data: data, encoding: .utf8) {
                    return try Client(yaml: yamlContent, ref: .file(url))
                }
            }
            return nil
        }

        try loadEntity(from: tenantPath).forEach { (tenant: Tenant) in
            delegate?.addEntity(entity: tenant)
        }

        try loadEntity(from: clientPath).forEach { (client: Client) in
            delegate?.addEntity(entity: client)
        }
    }

    func start() throws {
        try tenantFileMonitor.start()
        try clientFileMonitor.start()
    }

    func shutdown() {
        clientFileMonitor.stop()
        tenantFileMonitor.stop()
    }

    // MARK: - Private functions

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
                let yamlContent = try String(contentsOf: url)
                return try T.init(yaml: yamlContent, ref: .file(url))
            } catch {
                Log.error(
                        .init(
                                stringLiteral:
                                """
                                Can not read content or parse yaml from \(url.absoluteString):
                                \(error.localizedDescription) as \(T.self)
                                """.replacingOccurrences(of: "\n", with: "")
                        )
                )
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

fileprivate func eventHandler(
        event: FileChange,
        ofType: EntityFindResourceReferenceProtocol.Type,
        delegate: EntityLoaderProtocolFunctions?,
        loader loadEntity: EntityLoaderFunction
) {
    switch event {
    case .changed(let file):
        // remove if there is a file reference to the file path
        if let existingEntityOnFilePath = ofType.find(ref: .file(file)) {
            delegate?.removeEntity(entity: existingEntityOnFilePath)
        }
        do {
            // add the new entity
            delegate?.addEntity(entity: try loadEntity(file))
        } catch {
            Log.error("Changed file \(file.path) can not handle entity, \(error.localizedDescription)")
        }
    case .added(let file):
        do {
            // add the new entity
            delegate?.addEntity(entity: try loadEntity(file))
        } catch {
            Log.error("Added file \(file.path) can not handle entity, \(error.localizedDescription)")
        }
    case .deleted(let file):
        if let entityToRemove = ofType.find(ref: .file(file)) {
            delegate?.removeEntity(entity: entityToRemove)
        } else {
            Log.error(.init(stringLiteral: """
                                                  Can not remove \(type(of: ofType)) from file \(file.path),
                                                  because the reference is unknown
                                                  """.replacingOccurrences(of: "\n", with: " ")
            ))
        }
    }
}
