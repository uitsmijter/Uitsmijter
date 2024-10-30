import Foundation
import SwiftkubeClient
import SwiftkubeModel
import Vapor

struct TenantResource: KubernetesAPIResource, NamespacedResource, MetadataHavingResource,
        ReadableResource, CreatableResource, ListableResource {
    typealias List = TenantResourceList
    var apiVersion = "uitsmijter.io/v1"
    var kind = "Tenant"
    var metadata: meta.v1.ObjectMeta?
    var spec: TenantSpec
}

struct TenantResourceList: KubernetesResourceList {
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
    var apiVersion = "uitsmijter.io/v1"
    var kind = "clients"
    var items: [ClientResource]
}

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
        guard let kubeClient = KubernetesClient(logger: Log.main.getLogger()) else {
            throw EntityLoaderError.clientError
        }
        self.kubeClient = kubeClient

        try loadInitialTenants()
        try loadInitialClients()
    }

    func start() throws {
        Task {
            try await tenantListener()
        }
        Task {
            try await clientListener()
        }
    }

    func shutdown() {
        try? kubeClient.syncShutdown()
    }

    // MARK: - Initial Tenants
    private var namespaceSelector: NamespaceSelector {
        Constants.RUNTIME.SCOPED_KUBERNETES_CRD == true 
            ? .namespace(Constants.RUNTIME.UITSMIJTER_NAMESPACE) 
            : .allNamespaces
    }
    private func loadInitialTenants() throws {
        let group = DispatchGroup()
        group.enter()
        Task {
            do {
                let listTenants = try await kubeClient
                        .for(TenantResource.self, gvr: gvrTenants)
                        .list(in: namespaceSelector)

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
                        Log.error("Tenant \(name) can not be loaded from object \(item)")
                    }
                }
            } catch {
                Log.error("Unable to fetch initial tenants list: \(error)")
            }
            group.leave()
        }

        let result = group.wait(timeout: .distantFuture)
        switch result {
        case .timedOut:
            Log.error("Timeout reading initial tenants.")
        case .success:
            Log.info("Initial tenants loaded [\(EntityStorage.shared.tenants.count)]")
        }

    }

    private func entityFromResource(tenant item: TenantResource) throws -> Tenant {
        guard let namespace = item.metadata?.namespace else {
            let err = "Tenant can not be constructed, because it has no namespace."
            throw EntityLoaderError.listTenants(reason: err)
        }
        guard let name = item.name else {
            let err = "Tenant can not be constructed, because it has no name. Give each tenant a unique name."
            throw EntityLoaderError.listTenants(reason: err)
        }
        guard let uid = item.metadata?.uid else {
            let err = "Tenant can not be constructed, because it has no uid. Check your Kubernetes version."
            throw EntityLoaderError.listTenants(reason: err)
        }
        guard let uuid = UUID(uid) else {
            let err = "Tenant can not be constructed, because the uid is not a UUID: \(uid)"
            throw EntityLoaderError.listTenants(reason: err)
        }
        guard let resourceVersion = item.metadata?.resourceVersion else {
            let err = "Tenant can not be constructed, because it has no resourceVersion. Check your Kubernetes version"
            throw EntityLoaderError.listTenants(reason: err)
        }

        return Tenant(
                ref: EntityResourceReference.kubernetes(uuid, resourceVersion),
                name: namespace.appending("/").appending(name),
                config: item.spec
        )
    }

    private func tenantListener() async throws {
        let task = try kubeClient
                .for(TenantResource.self, gvr: gvrTenants)
                .watch(in: namespaceSelector)

        for try await item in task.start() {
            do {
                let tenant = try entityFromResource(tenant: item.resource)
                eventHandler(event: item.type, entity: tenant, ofType: Tenant.self, delegate: delegate)
            } catch {
                Log.error("Error while processing Tenant: \(error.localizedDescription), in \(item) ")
            }
        }
    }

    // MARK: - Initial Clients

    private func loadInitialClients() throws {
        let group = DispatchGroup()
        group.enter()
        Task {
            do {
                let listClients = try await kubeClient.for(
                        ClientResource.self,
                        gvr: gvrClients
                ).list(in: namespaceSelector)

                listClients.items.forEach { item in
                    guard let name = item.name else {
                        Log.error("Found client resource without a name: \(item)")
                        return
                    }

                    Log.info("Found client: \(name)")
                    if let client = try? entityFromResource(client: item) {
                        delegate?.addEntity(entity: client)
                    } else {
                        Log.error("Client \(name) can not be loaded from object \(item)")
                    }
                }
            } catch {
                Log.error("Unable to fetch initial clients list: \(error)")
            }
            group.leave()
        }
        let result = group.wait(timeout: .distantFuture)

        switch result {
        case .timedOut:
            Log.error("Timeout reading initial clients.")
        case .success:
            Log.info("Initial clients loaded [\(EntityStorage.shared.clients.count)]")
        }

    }

    private func entityFromResource(client item: ClientResource) throws -> Client {
        guard let name = item.name else {
            let err = "Client can not be constructed, because it has no name. Give each client a unique name."
            throw EntityLoaderError.listClients(reason: err)
        }
        guard let uid = item.metadata?.uid else {
            let err = "Client can not be constructed, because it has no uid. Check your Kubernetes version."
            throw EntityLoaderError.listClients(reason: err)
        }
        guard let uuid = UUID(uid) else {
            let err = "Client can not be constructed, because the uid is not a UUID: \(uid)"
            throw EntityLoaderError.listClients(reason: err)
        }
        guard let resourceVersion = item.metadata?.resourceVersion else {
            let err = "Client can not be constructed, because it has no resourceVersion. Check your Kubernetes version."
            throw EntityLoaderError.listClients(reason: err)
        }

        return Client(
                ref: EntityResourceReference.kubernetes(uuid, resourceVersion),
                name: name,
                config: item.spec
        )
    }

    private func clientListener() async throws {
        let task = try kubeClient.for(
            ClientResource.self, 
            gvr: gvrClients
        ).watch(in: namespaceSelector)

        for try await item in task.start() {
            do {
                let client = try entityFromResource(client: item.resource)
                eventHandler(event: item.type, entity: client, ofType: Client.self, delegate: delegate)
            } catch {
                Log.error("Error while processing client: \(error.localizedDescription), in \(item) ")
            }
        }
    }
}

// MARK: - Event handler used by Tenant and Client class.

fileprivate func eventHandler(
        event: EventType,
        entity: Entity,
        ofType: EntityFindResourceReferenceProtocol.Type,
        delegate: EntityLoaderProtocolFunctions?
) {
    switch event {
    case .added:
        if case let .kubernetes(resourceId, revision) = entity.ref,
           let existingClient = ofType.find(ref: .kubernetes(resourceId)) {
            if case let .kubernetes(_, existingRevision) = existingClient.ref,
               revision == existingRevision {
                Log.info("Skipped reloading \(type(of: ofType)) \(entity.name) as it is already loaded")
                return
            }
            delegate?.removeEntity(entity: existingClient)
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
