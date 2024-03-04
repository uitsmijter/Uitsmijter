import Foundation
import SotoS3
import Vapor

actor TenantTemplateLoader {
    enum TenantTemplateLoaderOperations {
        case create(tenant: Tenant)
        case remove(tenant: Tenant)
    }

    let fileManager = FileManager.default

    func operate(operation: TenantTemplateLoaderOperations) async {
        switch operation {
        case .create(let tenant):
            await create(tenant: tenant)
        case .remove(let tenant):
            remove(tenant: tenant)
        }
    }

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
                logger: Log.main.getLogger()
        )

        defer {
            do {
                try client.syncShutdown()
            } catch let err {
                Log.error("S3 client was unable to shut down: \(err) (\(err.localizedDescription))")
            }
        }

        guard let viewsDir = URL(string: Application().directory.viewsDirectory) else {
            Log.critical("Views directory could not be initialized")
            return
        }

        guard let tenantSlug = tenant.name.slug else {
            Log.error("S3 template not writeable due to missing tenant slug")
            return
        }

        // Create tenant template directory
        let tenantDir = viewsDir.appendingPathComponent(tenantSlug)
        do {
            try fileManager.createDirectory(
                    atPath: tenantDir.absoluteString,
                    withIntermediateDirectories: true
            )
        } catch let err {
            Log.error("S3 template directory could not be created: \(err) (\(err.localizedDescription))")
            return
        }

        // Load tempaltes from S3
        let s3 = S3(client: client, endpoint: templates.host) // swiftlint:disable:this identifier_name
        for file in ["index.leaf", "login.leaf", "logout.leaf", "error.leaf"] {
            let path = templates.path + "/" + file
            let fileRequest = S3.GetObjectRequest(bucket: templates.bucket, key: path)
            Log.info("Start creating: \(tenantDir.path)")
            do {
                let response: S3.GetObjectOutput = try await s3.getObject(fileRequest)
                guard let content = response.body?.asString() else {
                    Log.warning("S3 object \(s3Debug)/\(file) has no content")
                    continue
                }

                let targetFile = tenantDir.appendingPathComponent(file)
                Log.info("Write template to: \(targetFile.path)")
                if !fileManager.createFile(atPath: targetFile.path, contents: content.data(using: .utf8)) {
                    Log.error("S3 template \(targetFile) could not be written")
                    continue
                }

                Log.info("S3 template file created: \(targetFile)")
            } catch let err {
                Log.info("S3 object \(s3Debug)/\(file) not found: \(err) (\(err.localizedDescription))")
                continue
            }
            Log.info("Finish creating: \(tenantDir.path)")
        }
    }

    private func remove(tenant: Tenant) {
        // Ensure that the tenant has templates configured
        if tenant.config.templates == nil {
            return
        }

        guard let viewsDir = URL(string: Application().directory.viewsDirectory) else {
            Log.error("Views directory could not be found")
            return
        }

        guard let tenantSlug = tenant.name.slug else {
            Log.error("S3 template cant be celaned up due to missing tenant slug")
            return
        }

        // Cleanup tenant template directory
        let tenantDir = viewsDir.appendingPathComponent(tenantSlug)
        Log.info("Start removing: \(tenantDir.path)")
        do {
            try fileManager.removeItem(atPath: tenantDir.path)
        } catch let err {
            Log.error("S3 template directory could not be cleaned: \(err) (\(err.localizedDescription))")
        }
        Log.info("Finish removing: \(tenantDir.path)")
    }
}
