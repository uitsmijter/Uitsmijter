import Foundation
import Vapor

struct Template {

    /// Return the path to :page for the requested tenant, or the default if not set, or an error if the tenant is not
    /// known.
    ///
    /// - Parameters:
    ///   - name: Page name
    ///   - request: Vapor request
    /// - Returns: the path to the concrete template
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
            Log.info("No tenant for request host \(request.clientInfo?.requested.host ?? "-")", request: request)
            request.requestInfo = RequestInfo(description: "Please provide a client_id.")
            return "default/error"
        }

        guard let slug = tenant.name.slug else {
            if existTemplate(request: request, folder: "default", name: name) {
                return "default/\(name)"
            }
            return "default/index"
        }

        if existTemplate(request: request, folder: slug, name: name) {
            return "\(slug)/\(name)"
        }
        if existTemplate(request: request, folder: slug, name: "index") {
            return "\(slug)/index"
        }
        if existTemplate(request: request, folder: "default", name: name) {
            return "default/\(name)"
        }
        return "default/index"
    }
}
