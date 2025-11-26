import Foundation
import SwiftkubeClient
import SwiftkubeModel
import Logger

struct TenantStatus: Codable, Hashable, Equatable {
    var phase: String
    var clientCount: Int
    var activeSessions: Int
    var lastUpdated: String
}

struct TenantResource: KubernetesAPIResource, NamespacedResource, MetadataHavingResource,
                              ReadableResource, CreatableResource, ListableResource, StatusHavingResource {
    typealias List = TenantResourceList
    var apiVersion = "uitsmijter.io/v1"
    var kind = "Tenant"
    var metadata: meta.v1.ObjectMeta?
    var spec: TenantSpec
    var status: TenantStatus?
}

struct TenantResourceList: KubernetesResourceList {
    var metadata: SwiftkubeModel.meta.v1.ListMeta?

    var apiVersion = "uitsmijter.io/v1"
    var kind = "tenants"
    var items: [TenantResource]
}

struct ClientResource: KubernetesAPIResource, NamespacedResource, MetadataHavingResource,
                              ReadableResource, CreatableResource, ListableResource {
    typealias List = ClientResourceList
    var apiVersion = "uitsmijter.io/v1"
    var kind = "Client"
    var metadata: meta.v1.ObjectMeta?
    var spec: ClientSpec
}

struct ClientResourceList: KubernetesResourceList {
    var metadata: SwiftkubeModel.meta.v1.ListMeta?

    var apiVersion = "uitsmijter.io/v1"
    var kind = "clients"
    var items: [ClientResource]
}

@MainActor
struct EntityCRDLoader: EntityLoaderProtocol {

    let delegate: EntityLoaderProtocolFunctions?
    let kubeClient: KubernetesClient

    // Resource Types
    private let gvrTenants = GroupVersionResource(group: "uitsmijter.io", version: "v1", resource: "tenants")
    private let gvrClients = GroupVersionResource(group: "uitsmijter.io", version: "v1", resource: "clients")

    init(handler: EntityLoaderProtocolFunctions?) throws {
        // set delegate
        delegate = handler

        // init kube client
        guard let kubeClient = KubernetesClient(logger: Log.shared) else {
            throw EntityLoaderError.clientError
        }
        self.kubeClient = kubeClient

        // Don't block init() - initial loading will happen in start()
    }

    /// Starts loading and watching Kubernetes Custom Resources.
    ///
    /// Initiates asynchronous tasks to:
    /// 1. Load initial tenant and client resources from Kubernetes
    /// 2. Start watching for resource changes (add, modify, delete events)
    ///
    /// The loading and watching happen concurrently in separate tasks for
    /// tenants and clients to maximize startup performance.
    ///
    /// - Throws: Errors from Kubernetes client initialization
    func start() throws {
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

    /// Shuts down the Kubernetes client and stops watching resources.
    ///
    /// Performs a synchronous shutdown of the Kubernetes client connection,
    /// stopping all resource watches and cleaning up associated resources.
    nonisolated func shutdown() {
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
                Log.critical("Unable to fetch initial clients list: \(error)")
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

    // MARK: - Status Update

    /// Updates the status of a tenant resource in Kubernetes
    /// - Parameters:
    ///   - tenant: The tenant to update status for
    ///   - authCodeStorage: Optional auth code storage for counting active sessions
    func updateTenantStatus(tenant: Tenant, authCodeStorage: AuthCodeStorageProtocol?) async {
        Log.info("Attempting to update status for tenant: \(tenant.name)")

        // Extract namespace and name from tenant name (format: "namespace/name")
        let components = tenant.name.split(separator: "/")
        guard components.count == 2 else {
            Log.error("Invalid tenant name format: \(tenant.name). Expected 'namespace/name'")
            return
        }
        let namespace = String(components[0])
        let name = String(components[1])

        Log.info("Parsed tenant namespace=\(namespace), name=\(name)")

        do {
            // Fetch current resource to get latest metadata
            let currentResource = try await kubeClient
                .for(TenantResource.self, gvr: gvrTenants)
                .get(in: .namespace(namespace), name: name)

            // Count clients for this tenant
            let clientCount = delegate?.storage.clients.filter { client in
                client.config.tenantname == tenant.name
            }.count ?? 0

            // Count active sessions for this tenant
            var activeSessions = 0
            if let storage = authCodeStorage {
                Log.info("Counting active sessions for tenant: \(tenant.name)")
                activeSessions = await storage.count(tenant: tenant, type: .refresh)
                Log.info("Found \(activeSessions) active sessions for tenant: \(tenant.name)")
            } else {
                Log.warning("No authCodeStorage available for counting sessions")
            }

            // Create updated status
            let status = TenantStatus(
                phase: "Ready",
                clientCount: clientCount,
                activeSessions: activeSessions,
                lastUpdated: ISO8601DateFormatter().string(from: Date())
            )

            Log.info(
                "Updating Kubernetes status for \(tenant.name): clients=\(clientCount), sessions=\(activeSessions)"
            )

            // Create updated resource with new status
            var updatedResource = currentResource
            updatedResource.status = status

            // Update status subresource
            _ = try await kubeClient
                .for(TenantResource.self, gvr: gvrTenants)
                .updateStatus(in: .namespace(namespace), name: name, updatedResource)

            Log.info(
                "Successfully updated status for tenant \(tenant.name): \(clientCount) clients, \(activeSessions) sessions"
            )
        } catch {
            Log.error("Failed to update tenant status for \(tenant.name): \(error)")
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
