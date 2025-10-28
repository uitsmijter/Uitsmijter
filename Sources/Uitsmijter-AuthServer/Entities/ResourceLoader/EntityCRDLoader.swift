import Foundation
import SwiftkubeClient
import SwiftkubeModel
import Logger

struct TenantResource: KubernetesAPIResource, NamespacedResource, MetadataHavingResource,
                              ReadableResource, CreatableResource, ListableResource {
    public typealias List = TenantResourceList
    public var apiVersion = "uitsmijter.io/v1"
    public var kind = "Tenant"
    public var metadata: meta.v1.ObjectMeta?
    public var spec: TenantSpec
}

struct TenantResourceList: KubernetesResourceList {
    public var metadata: SwiftkubeModel.meta.v1.ListMeta?

    public var apiVersion = "uitsmijter.io/v1"
    public var kind = "tenants"
    public var items: [TenantResource]
}

struct ClientResource: KubernetesAPIResource, NamespacedResource, MetadataHavingResource,
                              ReadableResource, CreatableResource, ListableResource {
    public typealias List = ClientResourceList
    public var apiVersion = "uitsmijter.io/v1"
    public var kind = "Client"
    public var metadata: meta.v1.ObjectMeta?
    public var spec: ClientSpec
}

struct ClientResourceList: KubernetesResourceList {
    public var metadata: SwiftkubeModel.meta.v1.ListMeta?

    public var apiVersion = "uitsmijter.io/v1"
    public var kind = "clients"
    public var items: [ClientResource]
}

@MainActor
struct EntityCRDLoader: EntityLoaderProtocol {

    let delegate: EntityLoaderProtocolFunctions?
    let kubeClient: KubernetesClient

    // Resource Types
    private let gvrTenants = GroupVersionResource(group: "uitsmijter.io", version: "v1", resource: "tenants")
    private let gvrClients = GroupVersionResource(group: "uitsmijter.io", version: "v1", resource: "clients")

    public init(handler: EntityLoaderProtocolFunctions?) throws {
        // set delegate
        delegate = handler

        // init kube client
        guard let kubeClient = KubernetesClient(logger: Log.shared) else {
            throw EntityLoaderError.clientError
        }
        self.kubeClient = kubeClient

        // Don't block init() - initial loading will happen in start()
    }

    public func start() throws {
        // Load initial resources asynchronously, then start watching
        Task {
            try await loadInitialTenantsAsync()
            try await tenantListener()
        }
        Task {
            try await loadInitialClientsAsync()
            try await clientListener()
        }
    }

    public nonisolated func shutdown() {
        try? kubeClient.syncShutdown()
    }

    // MARK: - Initial Tenants
    private var namespaceSelector: NamespaceSelector {
        RuntimeConfiguration.SCOPED_KUBERNETES_CRD == true
            ? .namespace(RuntimeConfiguration.UITSMIJTER_NAMESPACE)
            : .allNamespaces
    }
    private func loadInitialTenantsAsync() async throws {
        let client = kubeClient
        let gvr = gvrTenants
        let namespace = namespaceSelector

        // Retry logic with exponential backoff for Kubernetes API readiness
        var retries = 0
        let maxRetries = 10
        var delayNanoseconds: UInt64 = 1_000_000_000  // 1 second in nanoseconds

        while retries < maxRetries {
            do {
                let listTenants = try await client
                    .for(TenantResource.self, gvr: gvr)
                    .list(in: namespace)

                listTenants.items.forEach { item in
                    guard let namespace = item.metadata?.namespace else {
                        Log.error("Found tenant resource without a namespace: \(item). Skip entity.")
                        return
                    }
                    guard let name = item.name else {
                        Log.error("Found tenant resource without a name: \(item). Skip entity.")
                        return
                    }
                    let fullname = "\(namespace)/\(name)"

                    Log.info("Found tenant: \(fullname)")
                    if let tenant = try? entityFromResource(tenant: item) {
                        delegate?.addEntity(entity: tenant)
                    } else {
                        Log.error("Tenant \(name) cannot be loaded from object \(item)")
                    }
                }
                Log.info("Initial tenants loaded from Kubernetes CRDs")
                return  // Success - exit retry loop
            } catch let error as SwiftkubeClientError {
                // Check if this is a 429 (TooManyRequests) error indicating API not ready
                if case .statusError(let status) = error, status.code == 429 {
                    retries += 1
                    if retries < maxRetries {
                        let delaySec = Double(delayNanoseconds) / 1_000_000_000.0
                        Log.info(
                            "Kubernetes API not ready (storage initializing), " +
                            "retry \(retries)/\(maxRetries) after \(String(format: "%.1f", delaySec))s"
                        )
                        try await Task.sleep(nanoseconds: delayNanoseconds)
                        delayNanoseconds = min(delayNanoseconds * 2, 30_000_000_000)  // max 30 seconds
                    } else {
                        Log.error("Unable to fetch initial tenants list after \(maxRetries) retries: \(error)")
                        throw error
                    }
                } else {
                    Log.error("Unable to fetch initial tenants list: \(error)")
                    throw error
                }
            } catch {
                Log.error("Unable to fetch initial tenants list: \(error)")
                throw error
            }
        }
    }

    private func entityFromResource(tenant item: TenantResource) throws -> Tenant {
        guard let namespace = item.metadata?.namespace else {
            let err = "Tenant cannot be constructed, because it has no namespace."
            throw EntityLoaderError.listTenants(reason: err)
        }
        guard let name = item.name else {
            let err = "Tenant cannot be constructed, because it has no name. Give each tenant a unique name."
            throw EntityLoaderError.listTenants(reason: err)
        }
        guard let uid = item.metadata?.uid else {
            let err = "Tenant cannot be constructed, because it has no uid. Check your Kubernetes version."
            throw EntityLoaderError.listTenants(reason: err)
        }
        guard let uuid = UUID(uid) else {
            let err = "Tenant cannot be constructed, because the uid is not a UUID: \(uid)"
            throw EntityLoaderError.listTenants(reason: err)
        }
        guard let resourceVersion = item.metadata?.resourceVersion else {
            let err = "Tenant cannot be constructed, because it has no resourceVersion. Check your Kubernetes version"
            throw EntityLoaderError.listTenants(reason: err)
        }

        return Tenant(
            ref: EntityResourceReference.kubernetes(uuid, resourceVersion),
            name: namespace.appending("/").appending(name),
            config: item.spec
        )
    }

    private func tenantListener() async throws {
        let task = try await kubeClient
            .for(TenantResource.self, gvr: gvrTenants)
            .watch(in: namespaceSelector)

        for try await item in await task.start() {
            do {
                let tenant = try entityFromResource(tenant: item.resource)
                eventHandler(event: item.type, entity: tenant, ofType: Tenant.self, delegate: delegate)
            } catch {
                Log.error("Error while processing Tenant: \(error.localizedDescription), in \(item) ")
            }
        }
    }

    // MARK: - Initial Clients

    private func loadInitialClientsAsync() async throws {
        let client = kubeClient
        let gvr = gvrClients
        let namespace = namespaceSelector

        // Retry logic with exponential backoff for Kubernetes API readiness
        var retries = 0
        let maxRetries = 10
        var delayNanoseconds: UInt64 = 1_000_000_000  // 1 second in nanoseconds

        while retries < maxRetries {
            do {
                let listClients = try await client.for(
                    ClientResource.self,
                    gvr: gvr
                ).list(in: namespace)

                listClients.items.forEach { item in
                    guard let name = item.name else {
                        Log.error("Found client resource without a name: \(item)")
                        return
                    }

                    Log.info("Found client: \(name)")
                    if let client = try? entityFromResource(client: item) {
                        delegate?.addEntity(entity: client)
                    } else {
                        Log.error("Client \(name) cannot be loaded from object \(item)")
                    }
                }
                Log.info("Initial clients loaded from Kubernetes CRDs")
                return  // Success - exit retry loop
            } catch let error as SwiftkubeClientError {
                // Check if this is a 429 (TooManyRequests) error indicating API not ready
                if case .statusError(let status) = error, status.code == 429 {
                    retries += 1
                    if retries < maxRetries {
                        let delaySec = Double(delayNanoseconds) / 1_000_000_000.0
                        Log.info(
                            "Kubernetes API not ready (storage initializing), " +
                            "retry \(retries)/\(maxRetries) after \(String(format: "%.1f", delaySec))s"
                        )
                        try await Task.sleep(nanoseconds: delayNanoseconds)
                        delayNanoseconds = min(delayNanoseconds * 2, 30_000_000_000)  // max 30 seconds
                    } else {
                        Log.error("Unable to fetch initial clients list after \(maxRetries) retries: \(error)")
                        throw error
                    }
                } else {
                    Log.error("Unable to fetch initial clients list: \(error)")
                    throw error
                }
            } catch {
                Log.error("Unable to fetch initial clients list: \(error)")
                throw error
            }
        }
    }

    private func entityFromResource(client item: ClientResource) throws -> UitsmijterClient {
        guard let name = item.name else {
            let err = "Client cannot be constructed, because it has no name. Give each client a unique name."
            throw EntityLoaderError.listClients(reason: err)
        }
        guard let uid = item.metadata?.uid else {
            let err = "Client cannot be constructed, because it has no uid. Check your Kubernetes version."
            throw EntityLoaderError.listClients(reason: err)
        }
        guard let uuid = UUID(uid) else {
            let err = "Client cannot be constructed, because the uid is not a UUID: \(uid)"
            throw EntityLoaderError.listClients(reason: err)
        }
        guard let resourceVersion = item.metadata?.resourceVersion else {
            let err = "Client cannot be constructed, because it has no resourceVersion. Check your Kubernetes version."
            throw EntityLoaderError.listClients(reason: err)
        }

        return Client(
            ref: EntityResourceReference.kubernetes(uuid, resourceVersion),
            name: name,
            config: item.spec
        )
    }

    private func clientListener() async throws {
        let task = try await kubeClient.for(
            ClientResource.self,
            gvr: gvrClients
        ).watch(in: namespaceSelector)

        for try await item in await task.start() {
            do {
                let client = try entityFromResource(client: item.resource)
                eventHandler(event: item.type, entity: client, ofType: UitsmijterClient.self, delegate: delegate)
            } catch {
                Log.error("Error while processing client: \(error.localizedDescription), in \(item) ")
            }
        }
    }
}

// MARK: - Event handler used by Tenant and Client class.

@MainActor
fileprivate func eventHandler(
    event: EventType,
    entity: Entity,
    ofType: EntityFindResourceReferenceProtocol.Type,
    delegate: EntityLoaderProtocolFunctions?
) {
    switch event {
    case .added:
        if case let .kubernetes(resourceId, revision) = entity.ref,
           let delegate,
           let existingClient = ofType.find(in: delegate.storage, ref: .kubernetes(resourceId)) {
            if case let .kubernetes(_, existingRevision) = existingClient.ref,
               revision == existingRevision {
                Log.info("Skipped reloading \(type(of: ofType)) \(entity.name) as it is already loaded")
                return
            }
            delegate.removeEntity(entity: existingClient)
        }
        delegate?.addEntity(entity: entity)
    case .modified:
        delegate?.removeEntity(entity: entity)
        delegate?.addEntity(entity: entity)
    case .deleted:
        delegate?.removeEntity(entity: entity)
    default:
        Log.error("Error loading \(type(of: ofType)) \(entity.ref?.description ?? "")")
    }
}
