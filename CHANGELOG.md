# 0.9.6

- Feature: Add tooling: `remove` - to clear out all docker resources and clean up build folder
- Feature: Add tooling: `code` - starts vscode in docker in brower

- Fix: Change encoding date from `.iso8601` to `.deferredToDate` 

- Change: Scripting Provider `fetch` method uses AsnHTTPClient instead of FoundationNetwork's URLSession

- Update: to Swift 5.9.2


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
