import Foundation
import SotoS3
import Logger

/// An actor responsible for loading and managing tenant-specific Leaf templates from S3-compatible storage.
///
/// `TenantTemplateLoader` orchestrates the complete lifecycle of tenant templates, from downloading
/// them from S3-compatible object storage to cleaning up local resources when tenants are removed.
/// Each tenant can have customized UI templates (login pages, error pages, etc.) stored in S3 and
/// deployed automatically when the tenant is created.
///
/// ## Overview
///
/// The loader operates as a Swift actor to ensure thread-safe template operations across concurrent
/// tenant creation and removal requests. It integrates with AWS S3 or S3-compatible storage services
/// (like MinIO, DigitalOcean Spaces, etc.) using the SotoS3 library.
///
/// ### Template Types
///
/// The loader fetches four standard Leaf template files for each tenant:
/// - `index.leaf` - Main landing page template
/// - `login.leaf` - User authentication form template
/// - `logout.leaf` - Logout confirmation template
/// - `error.leaf` - Error page template
///
/// Templates are stored in a tenant-specific directory named after the tenant's slug, allowing
/// multiple tenants to coexist with isolated template customizations.
///
/// ## Usage Example
///
/// ```swift
/// let loader = TenantTemplateLoader()
///
/// // Create templates for a new tenant
/// await loader.operate(operation: .create(tenant: myTenant))
///
/// // Later, when tenant is removed
/// await loader.operate(operation: .remove(tenant: myTenant))
/// ```
///
/// ## Configuration Requirements
///
/// For templates to be loaded, the tenant must have a `templates` configuration with:
/// - S3 endpoint host and region
/// - Bucket name and path prefix
/// - Access credentials (access key ID and secret)
///
/// If no template configuration exists, operations are safely skipped.
///
/// ## Topics
///
/// ### Creating the Loader
///
/// - ``init()``
///
/// ### Template Operations
///
/// - ``operate(operation:)``
/// - ``TenantTemplateLoaderOperations``
///
/// ## See Also
///
/// - ``Tenant``
/// - ``TenantConfig``
actor TenantTemplateLoader {

    /// Operations that can be performed on tenant templates.
    ///
    /// This enum defines the two fundamental operations for managing tenant template lifecycle:
    /// creating templates when a tenant is added, and removing them when a tenant is deleted.
    enum TenantTemplateLoaderOperations {
        /// Create template directory and download templates from S3 for the specified tenant.
        ///
        /// Downloads all standard templates (index, login, logout, error) from the tenant's
        /// configured S3 bucket and stores them in a local directory for use by the Leaf engine.
        case create(tenant: Tenant)

        /// Remove the template directory and all templates for the specified tenant.
        ///
        /// Cleans up local filesystem resources by removing the tenant's template directory
        /// and all contained template files.
        case remove(tenant: Tenant)
    }

    /// File system manager used for creating and removing template directories.
    ///
    /// This instance handles all file system operations including directory creation,
    /// file writing, and cleanup operations.
    let fileManager = FileManager.default

    /// Creates a new tenant template loader.
    ///
    /// The loader is initialized with a file manager and is ready to perform template
    /// operations immediately after creation.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let loader = TenantTemplateLoader()
    /// await loader.operate(operation: .create(tenant: tenant))
    /// ```
    init() {}

    /// Executes a template operation for a tenant.
    ///
    /// This method serves as the primary entry point for all template operations. It dispatches
    /// to the appropriate private method based on the operation type.
    ///
    /// - Parameter operation: The operation to perform (create or remove).
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let loader = TenantTemplateLoader()
    ///
    /// // Create templates for a tenant
    /// await loader.operate(operation: .create(tenant: myTenant))
    ///
    /// // Remove templates for a tenant
    /// await loader.operate(operation: .remove(tenant: oldTenant))
    /// ```
    ///
    /// ## Error Handling
    ///
    /// Errors during template operations are logged but do not throw. The method will:
    /// - Skip operations for tenants without template configuration
    /// - Log warnings for missing S3 objects
    /// - Log errors for file system or S3 client failures
    /// - Continue processing remaining templates on individual failures
    func operate(operation: TenantTemplateLoaderOperations) async {
        switch operation {
        case .create(let tenant):
            await create(tenant: tenant)
        case .remove(let tenant):
            await remove(tenant: tenant)
        }
    }

    /// Downloads tenant templates from S3 and creates local template directory.
    ///
    /// This private method handles the complete workflow of setting up templates for a new tenant:
    ///
    /// 1. Validates that the tenant has a template configuration
    /// 2. Creates an S3 client with the tenant's credentials
    /// 3. Creates a local directory for the tenant's templates
    /// 4. Downloads each standard template file from S3
    /// 5. Writes templates to the local filesystem
    ///
    /// ## Template Files
    ///
    /// The following template files are fetched from S3:
    /// - `index.leaf` - Landing page
    /// - `login.leaf` - Login form
    /// - `logout.leaf` - Logout confirmation
    /// - `error.leaf` - Error page
    ///
    /// ## Error Handling
    ///
    /// The method is resilient to partial failures:
    /// - Missing template files in S3 are logged as warnings and skipped
    /// - File system errors are logged and stop processing
    /// - S3 client errors are logged and processing continues for remaining files
    ///
    /// ## S3 Configuration
    ///
    /// Requires tenant configuration with:
    /// ```swift
    /// tenant.config.templates = TemplateConfig(
    ///     host: "s3.amazonaws.com",
    ///     region: "us-east-1",
    ///     bucket: "my-templates",
    ///     path: "tenant-slug",
    ///     access_key_id: "AKIAIOSFODNN7EXAMPLE",
    ///     secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    /// )
    /// ```
    ///
    /// - Parameter tenant: The tenant for which to create templates.
    private func create(tenant: Tenant) async {
        // Has templates configuration
        guard let templates = tenant.config.templates else {
            return
        }

        let s3Debug = "\(templates.host) (\(templates.region)) s3://\(templates.bucket)/\(templates.path)"
        Log.info("Loading templates for \(tenant.name) from S3 \(templates.access_key_id):***@\(templates.host)")

        let client = AWSClient(
            credentialProvider: .static(
                accessKeyId: templates.access_key_id,
                secretAccessKey: templates.secret_access_key
            ),
            httpClientProvider: .createNew,
            logger: Log.shared
        )

        defer {
            do {
                try client.syncShutdown()
            } catch let err {
                Log.error("S3 client was unable to shut down: \(err) (\(err.localizedDescription))")
            }
        }

        let viewsDirPath = await MainActor.run { viewsPath }
        guard let viewsDir = URL(string: viewsDirPath) else {
            Log.critical("Views directory could not be initialized")
            return
        }

        guard let tenantSlug = tenant.name.slug else {
            Log.error("S3 template not writable due to missing tenant slug")
            return
        }

        // Create tenant template directory
        let tenantDir = viewsDir.appendingPathComponent(tenantSlug)
        do {
            try fileManager.createDirectory(
                atPath: tenantDir.path,
                withIntermediateDirectories: true
            )
        } catch let err {
            Log.error("S3 template directory could not be created: \(err) (\(err.localizedDescription))")
            return
        }

        // Load templates from S3
        let s3 = S3(client: client, endpoint: templates.host) // swiftlint:disable:this identifier_name
        for file in ["index.leaf", "login.leaf", "logout.leaf", "error.leaf"] {
            let path = templates.path + "/" + file
            let fileRequest = S3.GetObjectRequest(bucket: templates.bucket, key: path)
            Log.debug("Creating S3 template directory: \(tenantDir.path)")
            do {
                let response: S3.GetObjectOutput = try await s3.getObject(fileRequest)
                guard let content = response.body?.asString() else {
                    Log.warning("S3 object \(s3Debug)/\(file) has no content")
                    continue
                }

                let targetFile = tenantDir.appendingPathComponent(file)
                Log.debug("Writing template to: \(targetFile.path)")
                if !fileManager.createFile(atPath: targetFile.path, contents: content.data(using: .utf8)) {
                    Log.error("S3 template \(targetFile) could not be written")
                    continue
                }

                Log.info("S3 template file created: \(targetFile)")
            } catch let err {
                Log.warning("S3 object \(s3Debug)/\(file) not found: \(err) (\(err.localizedDescription))")
                continue
            }
        }
    }

    /// Removes tenant template directory and all associated template files.
    ///
    /// This private method cleans up local filesystem resources when a tenant is removed:
    ///
    /// 1. Validates that the tenant has a template configuration
    /// 2. Locates the tenant's template directory by slug
    /// 3. Removes the entire directory and all contained files
    ///
    /// ## Directory Structure
    ///
    /// Templates are stored in a directory hierarchy:
    /// ```
    /// views/
    ///   └── tenant-slug/
    ///       ├── index.leaf
    ///       ├── login.leaf
    ///       ├── logout.leaf
    ///       └── error.leaf
    /// ```
    ///
    /// The entire `tenant-slug/` directory is removed during cleanup.
    ///
    /// ## Error Handling
    ///
    /// The method handles errors gracefully:
    /// - Returns silently if the tenant has no template configuration
    /// - Logs errors if the views directory cannot be located
    /// - Logs errors if the tenant slug is missing
    /// - Logs errors if directory removal fails (e.g., permission issues)
    ///
    /// - Parameter tenant: The tenant whose templates should be removed.
    private func remove(tenant: Tenant) async {
        // Ensure that the tenant has templates configured
        if tenant.config.templates == nil {
            return
        }

        let viewsDirPath = await MainActor.run { viewsPath }
        guard let viewsDir = URL(string: viewsDirPath) else {
            Log.error("Views directory could not be found")
            return
        }

        guard let tenantSlug = tenant.name.slug else {
            Log.error("S3 template cannot be cleaned up due to missing tenant slug")
            return
        }

        // Cleanup tenant template directory
        let tenantDir = viewsDir.appendingPathComponent(tenantSlug)
        Log.info("Removing S3 template directory: \(tenantDir.path)")
        do {
            try fileManager.removeItem(atPath: tenantDir.path)
            Log.debug("Finished removing S3 template directory: \(tenantDir.path)")
        } catch let err {
            Log.error("S3 template directory could not be cleaned: \(err) (\(err.localizedDescription))")
        }
    }
}
