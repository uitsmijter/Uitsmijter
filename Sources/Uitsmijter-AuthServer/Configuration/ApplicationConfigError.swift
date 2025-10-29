import Foundation

/// Errors that can occur during application configuration.
///
/// These errors represent configuration issues that prevent the application
/// from starting or loading entities correctly.
///
/// ## Error Cases
///
/// - ``directoryConfigError(_:)``: Directory access/validation failed
/// - ``clientWithoutName(_:)``: Client missing required name
/// - ``clientWithoutTenant(_:)``: Client missing parent tenant
/// - ``tenantNotFound(_:)``: Referenced tenant does not exist
/// - ``tenantNotParsable(_:)``: Tenant YAML files failed to parse
///
/// ## Usage
///
/// ```swift
/// do {
///     try validateConfiguration()
/// } catch ApplicationConfigError.directoryConfigError(let message) {
///     logger.error("Directory error: \(message)")
/// } catch ApplicationConfigError.tenantNotFound(let name) {
///     logger.error("Tenant '\(name)' not found")
/// }
/// ```
///
/// - SeeAlso: ``RuntimeConfiguration``, ``ApplicationConfiguration``
enum ApplicationConfigError: Error {
    /// The application could not access or validate a required directory.
    ///
    /// This error occurs during startup when the application cannot verify
    /// necessary directories for entities, templates, or resources.
    ///
    /// - Parameter String: A description of the directory issue
    ///
    /// ## Common Causes
    /// - Directory does not exist
    /// - Insufficient permissions
    /// - Invalid path format
    case directoryConfigError(String)

    /// A client configuration is missing a required name field.
    ///
    /// Every client must have a unique name identifier. This error indicates
    /// a client configuration was loaded without this required field.
    ///
    /// - Parameter String: Additional context about the client
    ///
    /// ## Resolution
    /// Add a valid `name` field to the client configuration YAML
    case clientWithoutName(String)

    /// A client configuration does not specify its parent tenant.
    ///
    /// Clients must be associated with a tenant. This error indicates the
    /// client configuration is missing the tenant reference.
    ///
    /// - Parameter String: Additional context about the client
    ///
    /// ## Resolution
    /// Add a valid `tenant` field to the client configuration
    case clientWithoutTenant(String)

    /// The specified tenant could not be found in the entity storage.
    ///
    /// A client references a tenant that has not been loaded or does not exist.
    /// Tenants must be loaded before their associated clients.
    ///
    /// - Parameter String: The name of the tenant that was not found
    ///
    /// ## Resolution
    /// - Ensure the tenant configuration file exists
    /// - Verify the tenant name matches exactly
    /// - Check tenant loading order
    case tenantNotFound(String)

    /// One or more tenant configurations could not be parsed from YAML.
    ///
    /// The YAML files contain syntax errors or invalid structure that prevents
    /// parsing into tenant entities.
    ///
    /// - Parameter [String]: List of tenant file paths that failed to parse
    ///
    /// ## Common Causes
    /// - Invalid YAML syntax
    /// - Missing required fields
    /// - Type mismatches in configuration values
    case tenantNotParsable([String])
}
