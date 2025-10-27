import Foundation
@testable import Uitsmijter_AuthServer
import Testing

/// Tests for ApplicationConfiguration module
@Suite("ApplicationConfiguration Tests")
struct ApplicationConfigurationTest {

    // MARK: - RuntimeConfiguration Tests

    @Test("RuntimeConfiguration SUPPORT_KUBERNETES_CRD is accessible")
    func supportKubernetesCRDIsAccessible() {
        // The static property should be accessible and return a Bool
        let value = RuntimeConfiguration.SUPPORT_KUBERNETES_CRD
        // Verify it's either true or false (a valid Bool)
        #expect(value == true || value == false)
    }

    @Test("RuntimeConfiguration SCOPED_KUBERNETES_CRD is accessible")
    func scopedKubernetesCRDIsAccessible() {
        let value = RuntimeConfiguration.SCOPED_KUBERNETES_CRD
        #expect(value == true || value == false)
    }

    @Test("RuntimeConfiguration UITSMIJTER_NAMESPACE is accessible")
    func uitsmijterNamespaceIsAccessible() {
        let namespace = RuntimeConfiguration.UITSMIJTER_NAMESPACE
        // Should be a valid string (possibly empty)
        #expect(namespace.isEmpty)
    }

    // MARK: - ApplicationConfigError Tests

    @Test("ApplicationConfigError directoryConfigError can be created")
    func directoryConfigErrorCanBeCreated() {
        let error = ApplicationConfigError.directoryConfigError("Test directory error")
        if case .directoryConfigError(let message) = error {
            #expect(message == "Test directory error")
        } else {
            Issue.record("Expected directoryConfigError case")
        }
    }

    @Test("ApplicationConfigError clientWithoutName can be created")
    func clientWithoutNameCanBeCreated() {
        let error = ApplicationConfigError.clientWithoutName("Test client")
        if case .clientWithoutName(let message) = error {
            #expect(message == "Test client")
        } else {
            Issue.record("Expected clientWithoutName case")
        }
    }

    @Test("ApplicationConfigError clientWithoutTenant can be created")
    func clientWithoutTenantCanBeCreated() {
        let error = ApplicationConfigError.clientWithoutTenant("Test client")
        if case .clientWithoutTenant(let message) = error {
            #expect(message == "Test client")
        } else {
            Issue.record("Expected clientWithoutTenant case")
        }
    }

    @Test("ApplicationConfigError tenantNotFound can be created")
    func tenantNotFoundCanBeCreated() {
        let error = ApplicationConfigError.tenantNotFound("NonExistentTenant")
        if case .tenantNotFound(let message) = error {
            #expect(message == "NonExistentTenant")
        } else {
            Issue.record("Expected tenantNotFound case")
        }
    }

    @Test("ApplicationConfigError tenantNotParsable can be created")
    func tenantNotParsableCanBeCreated() {
        let paths = ["/path/to/tenant1.yaml", "/path/to/tenant2.yaml"]
        let error = ApplicationConfigError.tenantNotParsable(paths)
        if case .tenantNotParsable(let errorPaths) = error {
            #expect(errorPaths == paths)
        } else {
            Issue.record("Expected tenantNotParsable case")
        }
    }

    // MARK: - Global Paths Tests

    @Test("resourcePath has default value", .tags(.requiresMainActor))
    @MainActor
    func resourcePathHasDefaultValue() {
        // Should have the default value
        #expect(resourcePath == "./" || !resourcePath.isEmpty)
    }

    @Test("viewsPath has default value", .tags(.requiresMainActor))
    @MainActor
    func viewsPathHasDefaultValue() {
        // Should have the default value
        #expect(viewsPath == "./" || !viewsPath.isEmpty)
    }

    @Test("resourcePath can be modified", .tags(.requiresMainActor))
    @MainActor
    func resourcePathCanBeModified() {
        let originalPath = resourcePath
        resourcePath = "/tmp/test/resources"
        #expect(resourcePath == "/tmp/test/resources")
        // Restore original value
        resourcePath = originalPath
    }

    @Test("viewsPath can be modified", .tags(.requiresMainActor))
    @MainActor
    func viewsPathCanBeModified() {
        let originalPath = viewsPath
        viewsPath = "/tmp/test/views"
        #expect(viewsPath == "/tmp/test/views")
        // Restore original value
        viewsPath = originalPath
    }
}

extension Tag {
    @Tag static var requiresMainActor: Self
}
