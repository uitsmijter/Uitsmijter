import Testing
@testable import Uitsmijter_AuthServer
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

@Suite("Tenant Configuration Algorithm Tests")
struct TenantConfigAlgorithmTest {

    @Test("Tenant with RS256 algorithm")
    func tenantWithRS256Algorithm() throws {
        let spec = TenantSpec(
            hosts: ["example.com"],
            jwt_algorithm: "RS256"
        )
        #expect(spec.effectiveJwtAlgorithm == "RS256")
    }

    @Test("Tenant with HS256 algorithm")
    func tenantWithHS256Algorithm() throws {
        let spec = TenantSpec(
            hosts: ["example.com"],
            jwt_algorithm: "HS256"
        )
        #expect(spec.effectiveJwtAlgorithm == "HS256")
    }

    @Test("Tenant with lowercase algorithm")
    func tenantWithLowercaseAlgorithm() throws {
        let spec = TenantSpec(
            hosts: ["example.com"],
            jwt_algorithm: "rs256"
        )
        #expect(spec.effectiveJwtAlgorithm == "RS256")
    }

    @Test("Tenant with mixed case algorithm")
    func tenantWithMixedCaseAlgorithm() throws {
        let spec = TenantSpec(
            hosts: ["example.com"],
            jwt_algorithm: "hS256"
        )
        #expect(spec.effectiveJwtAlgorithm == "HS256")
    }

    @Test("Tenant without algorithm falls back to environment RS256")
    func tenantWithoutAlgorithmFallsBackToEnvRS256() throws {
        setenv("JWT_ALGORITHM", "RS256", 1)
        defer { unsetenv("JWT_ALGORITHM") }

        let spec = TenantSpec(hosts: ["example.com"])
        #expect(spec.effectiveJwtAlgorithm == "RS256")
    }

    @Test("Tenant without algorithm falls back to environment HS256")
    func tenantWithoutAlgorithmFallsBackToEnvHS256() throws {
        setenv("JWT_ALGORITHM", "HS256", 1)
        defer { unsetenv("JWT_ALGORITHM") }

        let spec = TenantSpec(hosts: ["example.com"])
        #expect(spec.effectiveJwtAlgorithm == "HS256")
    }

    @Test("Tenant with invalid algorithm falls back to environment")
    func tenantWithInvalidAlgorithmFallsBack() throws {
        setenv("JWT_ALGORITHM", "HS256", 1)
        defer { unsetenv("JWT_ALGORITHM") }

        let spec = TenantSpec(
            hosts: ["example.com"],
            jwt_algorithm: "INVALID"
        )
        #expect(spec.effectiveJwtAlgorithm == "HS256")
    }

    @Test("Defaults to HS256 when nothing is set")
    func defaultsToHS256() throws {
        unsetenv("JWT_ALGORITHM")

        let spec = TenantSpec(hosts: ["example.com"])
        #expect(spec.effectiveJwtAlgorithm == "HS256")
    }

    @Test("Tenant algorithm overrides environment variable")
    func tenantAlgorithmOverridesEnvironment() throws {
        setenv("JWT_ALGORITHM", "RS256", 1)
        defer { unsetenv("JWT_ALGORITHM") }

        let spec = TenantSpec(
            hosts: ["example.com"],
            jwt_algorithm: "HS256"
        )

        #expect(spec.effectiveJwtAlgorithm == "HS256")
    }

    @Test("Tenant RS256 overrides environment HS256")
    func tenantAlgorithmRS256OverridesEnvironmentHS256() throws {
        setenv("JWT_ALGORITHM", "HS256", 1)
        defer { unsetenv("JWT_ALGORITHM") }

        let spec = TenantSpec(
            hosts: ["example.com"],
            jwt_algorithm: "RS256"
        )

        #expect(spec.effectiveJwtAlgorithm == "RS256")
    }

    @Test("Multiple tenants with different algorithms")
    func multipleTenantsWithDifferentAlgorithms() throws {
        let tenant1 = TenantSpec(
            hosts: ["tenant1.example.com"],
            jwt_algorithm: "HS256"
        )
        let tenant2 = TenantSpec(
            hosts: ["tenant2.example.com"],
            jwt_algorithm: "RS256"
        )
        let tenant3 = TenantSpec(
            hosts: ["tenant3.example.com"]
        )

        #expect(tenant1.effectiveJwtAlgorithm == "HS256")
        #expect(tenant2.effectiveJwtAlgorithm == "RS256")
        #expect(tenant3.effectiveJwtAlgorithm == "HS256")
    }

    @Test("Tenant from YAML with algorithm")
    func tenantFromYAMLWithAlgorithm() throws {
        let yaml = """
        name: test-tenant
        config:
          hosts:
            - example.com
          jwt_algorithm: RS256
          providers:
            - test-provider.js
        """

        let tenant = try Tenant(yaml: yaml)
        #expect(tenant.config.effectiveJwtAlgorithm == "RS256")
    }

    @Test("Tenant from YAML without algorithm")
    func tenantFromYAMLWithoutAlgorithm() throws {
        let yaml = """
        name: test-tenant
        config:
          hosts:
            - example.com
          providers:
            - test-provider.js
        """

        let tenant = try Tenant(yaml: yaml)
        #expect(tenant.config.effectiveJwtAlgorithm == "HS256")
    }
}
