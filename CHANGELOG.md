# 0.10.0

- Feature: **RFC 7517 (JSON Web Key)** - Full implementation of JWKS endpoint at `/.well-known/jwks.json` with RSA public key distribution, supporting RS256 JWT signing algorithm with automatic key rotation and `kid` header support
- Feature: **RS256 JWT Signing** - Asymmetric RSA-2048 signature algorithm support with seamless migration path from HS256, configurable via `JWT_ALGORITHM` environment variable
- prerelease
- Feature: **OAuth 2.0 Token Revocation (RFC 7009)** - New `/revoke` endpoint allows clients to invalidate access tokens and refresh tokens, with cascading revocation support and Prometheus metrics
- Feature: **OpenID Connect Discovery 1.0** endpoint at `/.well-known/openid-configuration` with full multi-tenant support, allowing clients to automatically discover provider capabilities and endpoints
- Feature: **E2E Test Filtering** - New `--filter` flag for `./tooling.sh e2e` command allows selective test execution for faster development cycles
- Feature: Enhanced **Kubernetes API** with automatic retry logic for improved reliability when loading tenant and client configurations from CRDs
- Feature: Improved **Helm Chart** with default resource limits helper for easier production deployments

- Fix: OpenID Discovery endpoint now includes `revocation_endpoint` field
- Fix: **OpenID Discovery endpoint** now includes `end_session_endpoint` field pointing to `/logout` for RP-initiated logout support
- Fix: **JSON output formatting** - URLs in `.well-known/openid-configuration` no longer have escaped forward slashes for better compatibility with strict parsers
- Fix: **Redis connection stability** - Connection pool no longer blocks startup, graceful handling of DNS resolution failures, and improved timeout configuration
- Fix: **S3 template loading** race condition in multi-tenant environments
- Fix: **PKCE validation** order in OAuth2 authorization flow
- Fix: **JSON encoder/decoder** date strategy mismatch causing serialization issues
- Fix: **MainActor deadlock** in EntityCRDLoader initialization
- Fix: **Stdout buffering** in containerized environments for immediate log visibility
- Fix: Translation provider initialization to use correct resource path in Docker environments
- Fix: Helm template YAML indentation issues

- Change: **Swift 6.2 Upgrade** - Complete migration to Swift 6.2 with full concurrency support, actor isolation, and Sendable conformance
- Change: **Server target renamed** to `Uitsmijter-AuthServer` for better clarity
- Change: **Controller structure** reorganized with flattened directory structure for improved maintainability
- Change: Removed WebKitGTK compatibility layer (now handled by Buildbox 4.1.1)

- Update: **Redis to 8.2.2** with Sentinel support for high availability
- Update: **Buildbox to 4.1.1** with improved Swift 6.2 support
- Update: **SwiftLint** to latest version with auto-fix capabilities
- Update: **FileMonitor to 1.2.1** with Swift 6.2 concurrency fixes

- Improvement: **Logging system** - Complete rewrite as independent module with NDJSON format support, improved error messages, spelling and grammar fixes
- Improvement: **JavaScript Provider** converted to actor for thread-safe script execution
- Improvement: **AuthCodeStorage** converted to actor with improved garbage collection in Docker environments
- Improvement: **Redis replicas** default with 3 replicas for better reliability
- Improvement: Comprehensive **DocC documentation** added throughout codebase
- Improvement: **Test infrastructure** - Fixed flaky tests caused by parallel execution, improved test filtering, and added comprehensive test coverage
- Improvement: **Tooling script** documentation with detailed function descriptions
- Improvement: Code quality with zero SwiftLint violations and zero compiler warnings

# 0.9.7

- Feature: Deployment resource request and limits can be set in helm values.yaml
- Improvement: Redis is healthy log is now a debug only mesage

# 0.9.6

- Feature: New Tooling Command `code`: Launches Visual Studio Code in a Dockerized environment directly within your browser, allowing seamless code editing without setup
- Feature: New Tooling Command `remove`: Efficiently cleans up your Docker environment by removing all Docker resources and clearing the build folder
- Feature: Namespace Scoped Tenants and Clients support for namespace-scoped tenants and clients, making it easier to define boundaries and permissions specific for various projects working on one cluster
- Feature: Support for Docker-Mode installations

- Fix: The encoding date format has been switched from `.iso8601` to `.deferredToDate`
- Fix: The error message for missing pages has been updated to `NOT_FOUND` (replacing the prior `ERRORS.NO_TENANT`)
- Fix: Log entries now display the correct origin, improving traceability and making debugging easier

- Change: The Scripting Provider `fetch` method now leverages `AsyncHTTPClient` rather than `FoundationNetwork`'s `URLSession`
- Change: End-to-end tests running in `--fast` mode will now default to using Chromium, ensuring consistent behavior and results across tests
- Change: To improve test compatibility, we have removed the "webp" support for the default login page of Uitsmijte End-To-End-Test
- Change: Redis instances are now clearly identified with `uitsmijter-session-master` and `uitsmijter-session-slave`, helping to avoid confusion and enhancing configuration clarity

- Update: to Swift 5.9.2
- Update buildbox to 2.3.0
- Update Vapor to 4.106.1

- Improvement: The `code` tooling command now utilizes its own build folder, streamlining the workspace and reducing cross-dependencies
- Improvement: The `test` command now supports an optional filter, allowing you to selectively run tests and focus on specific areas of the codebase
- Improvement: To better align documentation and reduce ambiguity, "Littleletetr" has been renamed to "Ham" across all relevant documentation and testing szenarios

# 0.9.5

Released at 10.11.2023

- Public availability on GitHUb
- GitHub Actions
- Public Helm Chats

# 0.9.4

Released at 03.10.2023

- Feature: Allow loading custom tenant templates from S3 buckets
- Feature: Make imprint, privacy policy and registration links configurable in tenant config

- Fix: Check cookie on silent login to prevent login across sites
- Fix: Check for referrers on requests
- Fix: Check login identifier on requests
- Fix: Crashloops in logger

- Build: Fixed release naming generation
- Build: Use image-processor image from GitHub repo
- Build: Use buildbox image from GitHub repo
- Build: Refactor tooling.sh dependencies

- Test: Check that response types match the requests

- Improvement: Unified logger output formatting
- Improvement: Cleanup codebase
- Improvement: Set the k8s application state to ready when redis is available
- Improvement: Cleanup of the preinstalled `uitsmijter-tenant`, for testing it only listens on localhost

- Update: async-http-client, async-kit, swiftkube, console-kit etc.

# 0.9.3

Released at 13.09.2023

- Feature: Show a login spinner when login button is pressed
- Feature: Redis health check is implemented
- Feature: Check if user is still valid
- Feature: EE helm charts
- Feature: Optimised images
- Feature: Silent login
- Feature: Add allowed scopes from Tenants into user profile

- Change: Remove marketing folder
- Change: StringManipulationFunction is now a implementation detail of the entity loades
- Change: Pipeline is more WPF-Style
- Change: Adjust logo and styleguide

- Fix: Cleanup artefacts
- Fix: Cleanup test cluster after e2e tests
- Fix: Various linter fixes
- Fix: Oauth login when tenant could not be selected

- Build: resize images only if file is not present
- Build: Docker build scripts improved in environments settings

- Test: Remove cert-manager from test cluster
- Test: Set timeout to 5m for the test cluster
- Test: Hotfix for webkit tests when background images loads too slow
- Test: Removed localhost, that are no longer needed

- Improvement: Documentation
- Improvement: Use URLSearchParams to construct query params in test
- Improvement: Split controllers for login and logout
- Improvement: Implement a url `appending` function for linux
- Improvement: Get client information in `enrichClientInfo` with payload
- Improvement: Refactoring authorize controller, and login controller

# 0.9.2

Released at 15.08.2023

- Feature: Show version at /versions, if not denied by config
- Feature: Load Tenants and Clients from Kubernetes Resource
- Feature: Reload von Tenants und Clients, when file has changed
- Feature: Reload von Tenants und Clients from Kubernetes, when resource has changed
- Feature: Translations fallback to english if no localize version is found
- Feature: User invalidation after deleting the user - Add new BackendProvider

- Change: Rename email to username
- Change: Rename Passthrough-Mode in Interceptor-Mode
- Change: Change docker user
- Change: New Uitsmijter Logo
- Change: Provide tenant and client as a middleware

- Fix: Double adding of tenants
- Fix: Remove annotation to unused COOKIE_DOMAIN environment variable
- Fix: URL-Encode redirect parameter
- Fix: Use Tenant interceptor cookie domain on Logout

- Build: enable swiftlint
- Build: Zero Warnings Compilation
- Build: introduce e2e tests with playwright

- Test: Testing helm charts
- Test: End-to-End tests

- Improvement: Load Tenant from Client computed propery.
- Improvement: Revise Documentation with new naming
- Improvement: Tooling & Build-System
- Improvement: Cleanup Dockerfiles
- Improvement: Documentation
- Improvement: Logging
- Improvement: EntityLoader conforms to .default/.main pattern
- Improvement: Local e2e test to become faster
- Improvement: Local builds become faster

- Update: swiftkube/client to 0.15.0
- Update: FileMonitor to 1.1.0

# 0.9.1

- Start development from the sources from different implementations
