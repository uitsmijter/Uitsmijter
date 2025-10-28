import Foundation

// MARK: - Configuration Errors

/// Errors that can occur during application configuration.
///
/// These errors represent configuration issues that prevent the application
/// from starting or loading entities correctly.
enum ApplicationConfigError: Error {
    /// The application could not access or validate a required directory.
    /// - Parameter String: A description of the directory issue
    case directoryConfigError(String)

    /// A client configuration is missing a required name field.
    /// - Parameter String: Additional context about the client
    case clientWithoutName(String)

    /// A client configuration does not specify its parent tenant.
    /// - Parameter String: Additional context about the client
    case clientWithoutTenant(String)

    /// The specified tenant could not be found in the entity storage.
    /// - Parameter String: The name of the tenant that was not found
    case tenantNotFound(String)

    /// One or more tenant configurations could not be parsed from YAML.
    /// - Parameter [String]: List of tenant file paths that failed to parse
    case tenantNotParsable([String])
}

// MARK: - Global Paths

/// The base path to application resources directory.
///
/// This path is set during application startup and points to the directory
/// containing configuration files, templates, and other resources.
///
/// - Note: Must be accessed from the main actor context.
/// - SeeAlso: ``viewsPath``
@MainActor
var resourcePath = "./"

/// The path to the views/templates directory.
///
/// This path is set during application startup and points to the directory
/// containing Leaf templates for rendering HTML pages.
///
/// - Note: Must be accessed from the main actor context.
/// - SeeAlso: ``resourcePath``
@MainActor
var viewsPath = "./"

// MARK: - Runtime Configuration

/// Runtime configuration settings loaded from environment variables.
///
/// This structure provides access to runtime configuration that affects
/// application behavior, particularly for Kubernetes integration.
///
/// ## Topics
///
/// ### Kubernetes Support
/// - ``SUPPORT_KUBERNETES_CRD``
/// - ``SCOPED_KUBERNETES_CRD``
/// - ``UITSMIJTER_NAMESPACE``
struct RuntimeConfiguration {

    /// Indicates whether Kubernetes Custom Resource Definition (CRD) support is enabled.
    ///
    /// When enabled, the application will load tenant and client configurations
    /// from Kubernetes CRDs in addition to file-based configurations.
    ///
    /// - Environment: `SUPPORT_KUBERNETES_CRD`
    /// - Default: `false`
    static let SUPPORT_KUBERNETES_CRD: Bool = {
        guard let value = ProcessInfo.processInfo.environment["SUPPORT_KUBERNETES_CRD"] else {
            return false
        }
        return Bool(value) ?? false
    }()

    /// Indicates whether CRD watching is scoped to a specific namespace.
    ///
    /// When `true`, the application only watches CRDs in the namespace specified
    /// by ``UITSMIJTER_NAMESPACE``. When `false`, watches all namespaces.
    ///
    /// - Environment: `SCOPED_KUBERNETES_CRD`
    /// - Default: `false`
    /// - SeeAlso: ``UITSMIJTER_NAMESPACE``
    static let SCOPED_KUBERNETES_CRD: Bool = {
        guard let value = ProcessInfo.processInfo.environment["SCOPED_KUBERNETES_CRD"] else {
            return false
        }
        return Bool(value) ?? false
    }()

    /// The Kubernetes namespace to watch for CRDs when scoped mode is enabled.
    ///
    /// Only used when ``SCOPED_KUBERNETES_CRD`` is `true`. Specifies which
    /// namespace the application should watch for tenant and client CRDs.
    ///
    /// - Environment: `UITSMIJTER_NAMESPACE`
    /// - Default: `""` (empty string)
    /// - SeeAlso: ``SCOPED_KUBERNETES_CRD``
    static let UITSMIJTER_NAMESPACE: String =
        ProcessInfo.processInfo.environment["UITSMIJTER_NAMESPACE"] ?? ""
}
