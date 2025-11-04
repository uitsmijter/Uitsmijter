import Foundation

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
