import Foundation
import Vapor
import Logger

// MARK: - Template Resolver

/// Resolves Leaf template paths based on tenant configuration.
///
/// This utility handles the logic for finding the correct template file for a given
/// page and tenant. It supports tenant-specific template overrides while falling back
/// to default templates when tenant-specific ones aren't available.
///
/// ## Template Resolution
///
/// Templates are resolved in the following priority order:
/// 1. Tenant-specific template: `views/{tenant-slug}/{page}.leaf`
/// 2. Tenant index template: `views/{tenant-slug}/index.leaf`
/// 3. Default page template: `views/default/{page}.leaf`
/// 4. Default index template: `views/default/index.leaf`
///
/// ## Directory Structure
///
/// ```
/// views/
///   ├── default/
///   │   ├── index.leaf
///   │   ├── login.leaf
///   │   └── error.leaf
///   ├── tenant-a/
///   │   ├── login.leaf     # Custom login for tenant-a
///   │   └── index.leaf
///   └── tenant-b/
///       └── index.leaf
/// ```
///
/// ## Example Usage
///
/// ```swift
/// // Get login template for current tenant
/// let path = Template.getPath(page: "login", request: req)
/// return try await req.view.render(path, context)
/// ```
///
/// ## Topics
///
/// ### Template Resolution
/// - ``getPath(page:request:)``
///
/// - SeeAlso: ``Tenant``
/// - SeeAlso: ``ClientInfo``
struct Template {

    /// Resolves the template path for a given page and request tenant.
    ///
    /// This method determines the appropriate Leaf template file to use based on
    /// the tenant associated with the request. If no tenant is found or no tenant-specific
    /// template exists, it falls back to default templates.
    ///
    /// ## Tenant Resolution
    ///
    /// The tenant is extracted from `request.clientInfo?.tenant`. If no tenant is
    /// available, an error template is returned.
    ///
    /// ## Fallback Strategy
    ///
    /// 1. Try `{tenant-slug}/{page}.leaf`
    /// 2. Try `{tenant-slug}/index.leaf`
    /// 3. Try `default/{page}.leaf`
    /// 4. Use `default/index.leaf`
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Request for tenant "example" with custom login
    /// let path = Template.getPath(page: "login", request: req)
    /// // Returns: "example/login"
    ///
    /// // Request for tenant "other" without custom login
    /// let path = Template.getPath(page: "login", request: req)
    /// // Returns: "default/login"
    /// ```
    ///
    /// - Parameters:
    ///   - name: The page name (without .leaf extension)
    ///   - request: The Vapor request containing tenant information
    /// - Returns: The relative path to the template (without .leaf extension)
    ///
    /// - SeeAlso: ``Tenant``
    /// - SeeAlso: ``ClientInfo/tenant``
    static func getPath(page name: String, request: Request) -> String {

        /// Inner function to check if a template exists
        ///
        /// - Parameters:
        ///   - req: Request
        ///   - folder: the tenants slug
        ///   - name: name of teh template
        /// - Returns: True when the template exists
        func existTemplate(request req: Request, folder: String, name: String) -> Bool {
            FileManager.default.fileExists(
                atPath: "\(req.application.directory.viewsDirectory)/\(folder)/\(name).leaf"
            )
        }

        guard let tenant: Tenant = request.clientInfo?.tenant else {
            Log.info("No tenant for request host \(request.clientInfo?.requested.host ?? "-")", requestId: request.id)
            request.requestInfo = RequestInfo(description: "Please provide a client_id.")
            return "default/error"
        }

        guard let slug = tenant.name.slug else {
            if existTemplate(request: request, folder: "default", name: name) {
                return "default/\(name)"
            }
            return "default/index"
        }
        Log.info("Template get page for tenant with slug \(slug)")

        if existTemplate(request: request, folder: slug, name: name) {
            Log.info("Template page \(name) exists for tenant with slug \(slug)")
            return "\(slug)/\(name)"
        }
        if existTemplate(request: request, folder: slug, name: "index") {
            Log.info("Template page did not exists for tenant with slug \(slug), returning index")
            return "\(slug)/index"
        }
        if existTemplate(request: request, folder: "default", name: name) {
            Log.info("Template page \(name) from default for \(slug)")
            return "default/\(name)"
        }

        Log.error("No Template page found for tenant with slug \(slug)!")
        return "default/index"
    }
}
