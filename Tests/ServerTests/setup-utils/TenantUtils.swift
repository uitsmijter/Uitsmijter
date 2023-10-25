import Foundation
import XCTest
@testable import Server

func setupTenant() {
    EntityStorage.shared.tenants.removeAll()
    EntityStorage.shared.clients.removeAll()

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
    let (inserted, _) = EntityStorage.shared.tenants.insert(tenant)
    XCTAssertTrue(inserted)

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
    EntityStorage.shared.clients = [client]
}
