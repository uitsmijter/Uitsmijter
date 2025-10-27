import Foundation
import SotoS3
import Logger

public actor TenantTemplateLoader {

    public enum TenantTemplateLoaderOperations {
        case create(tenant: Tenant)
        case remove(tenant: Tenant)
    }

    let fileManager = FileManager.default

    public init() {}

    public func operate(operation: TenantTemplateLoaderOperations) async {
        switch operation {
        case .create(let tenant):
            await create(tenant: tenant)
        case .remove(let tenant):
            await remove(tenant: tenant)
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
