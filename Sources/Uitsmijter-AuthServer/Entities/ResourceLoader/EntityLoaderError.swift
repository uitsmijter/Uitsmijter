import Foundation

/// Errors that can occur during entity loading operations.
///
/// These errors represent failures when loading tenant and client configurations
/// from various sources such as files, Kubernetes CRDs, or other storage backends.
enum EntityLoaderError: Error {
    /// Failed to load an entity from the specified URL.
    /// - Parameter from: The URL that could not be loaded
    case canNotLoad(from: URL)

    /// No entity loader has been registered to handle the loading operation.
    case noLoaderRegistered

    /// Failed to initialize or communicate with the Kubernetes client.
    case clientError

    /// Failed to list tenant resources.
    /// - Parameter reason: Optional description of why the operation failed
    case listTenants(reason: String?)

    /// Failed to list client resources.
    /// - Parameter reason: Optional description of why the operation failed
    case listClients(reason: String?)
}
