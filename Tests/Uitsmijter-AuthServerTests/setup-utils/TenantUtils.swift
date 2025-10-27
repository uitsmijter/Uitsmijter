import Foundation
import Testing
import Vapor
@testable import Uitsmijter_AuthServer

@MainActor
func setupTenant(app: Application) async {
    app.entityStorage.tenants.removeAll()
    app.entityStorage.clients.removeAll()

    var tenantConfig = TenantSpec(hosts: ["example.com", "example.org"])
    tenantConfig.providers.append(
        """
             class UserLoginProvider {
                isLoggedIn = false;
                constructor(credentials) {
                     console.log("Credentials:", credentials.username, credentials.password);
                     if(credentials.username == "ok@example.com"){
                          this.isLoggedIn = true;
                     }
                     commit(credentials.username == "ok@example.com");
                }

                // Getter
                get canLogin() {
                   return this.isLoggedIn;
                }

                get userProfile() {
                   return {
                      name: "Sander Foles",
                      species: "Musician",
                   };
                }
             }
            """
    )
    let tenant = Tenant(name: "Test Tenant", config: tenantConfig)
    let (inserted, _) = app.entityStorage.tenants.insert(tenant)
    #expect(inserted)

    let client = Client(
        name: "First Client",
        config: ClientSpec(
            ident: UUID(),
            tenantname: tenant.name,
            redirect_urls: [
                ".*\\.?example\\.(org|com)/?(.+)?",
                "foo\\.example\\.com",
                "wikipedia.org"
            ],
            scopes: ["read"],
            referrers: [
                "example.com"
            ]
        )
    )
    app.entityStorage.clients = [client]
}
