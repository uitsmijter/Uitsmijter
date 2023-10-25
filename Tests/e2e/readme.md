# Uitsmijter Tests / Test "Clusters"

This document lists all testable cases and their corresponding test coverage.
All tests should be linked from the test cases that they cover.
Tests should normally be run using english as the test language.
Test configs are provided in [/Deployment/e2e/uitsmijter-*.yml](../../Deployment/e2e) and can be extended as needed
(and documented here).

End-2-End test should be use-case based.
A use-case needs some clients with tenants to allow a user to follow an auth flow.
Most use-cases should be covered by the Cheese Tenant. It has OAuth & Interceptor modes enabled.
The BNBC Tenant only uses interceptor mode and Ham should be used to test the external backend service and
not-silent-logins.

```
Cheese (Tenant) - Allow @example.com - interceptor - default silent login 
  Hosts: login.example.com / id.example.com / missing-tenant.example.com (not in tenant config but forwarded)
  Clients:
  - cheese.example.com (oauth2 website login, secret)
  - cookbooks.example.com (interceptor)
  - toast.example.com (interceptor)
  - goat.example.com (interceptor)
  - api.example.com (mobile app)
  - spa.example.net (single page application)
BNBC (Tenant) - Allow all - interceptor - enable silent login
  Host: bnbc.example (independent)
  login.bnbc.example
  Clients:
    - blog.bnbc.example (OAuth)
    - shop.bnbc.example (OAuth)
Ham (Tenant) - Backend service http://checkcredentials.checkcredentials.svc.cluster.local/validate-login - interceptor - no silent login - custom template
  Host: id.ham.test <- authentificatiomn server
  Clients:
  - page.ham.test (interceptor -> login.ham.test)
  - api1.ham.test (OAuth)
  - api2.ham.test (OAuth)
```

## Users

On **Cheese**, all users with `@example.com` are accepted. A special user named `delayed-login@example.com` pauses
the login process for 5 seconds.

## Options

### Server Config

:label: Integration & e2e

* Is the server reacting as it should when started (port / ip binding, logging, token times etc.)
* Test responses to endpoints (GET by default if not noted otherwise):
    * /
    * /health
    * /versions
    * /metrics
    * /login
    * /logout (GET & POST)
    * /logout/finalize
    * /interceptor
    * /authorize
    * /token (POST)
    * /token/info

| ENV / Argument                      | Default                          | Description                                         |
|-------------------------------------|----------------------------------|-----------------------------------------------------|
| ~~`--hostname`~~                    | ~~`127.0.0.1`~~                  | ~~Set host name,~~ not registered                   |
| ~~`--port`~~                        | ~~`8080`~~                       | ~~Set server port,~~ not registered                 |
| `--help`                            |                                  | Show help                                           |
| `routes`                            |                                  | Show routes                                         |
| `boot`                              |                                  | Only boot the application                           |
| `serve`                             |                                  | Run the app                                         |
| `PUBLIC_DOMAIN`                     | `localhost:8080`                 |
| `COOKIE_EXPIRATION_IN_DAYS`         | `7`                              |
| `SECURE`                            | `false`                          | Token cookie secure flag                            |
| `TOKEN_EXPIRATION_IN_HOURS`         | `2`                              |
| `TOKEN_REFRESH_EXPIRATION_IN_HOURS` | `720`                            |
| `SUPPORT_KUBERNETES_CRD`            | `false` (true in k8s deployment) |
| `DISPLAY_VERSION`                   | `true`                           |
| `LOG_LEVEL`                         | `info`                           |
| `LOG_FORMAT`                        | `console`                        |
| `ENVIRONMENT`, `-e`, `--env`        | `production` on release          | Should be set to `production` (default for release) |
| `REDIS_HOST`                        | `localhost`                      | Used in production, else in-memory                  |
| `REDIS_PASSWORD`                    |                                  |
| `JWT_SECRET`                        | `[random 64 characters string]`  |

### Helm Deployment

:label: Integration

* Default deployment works
    * All services deployed
    * All configs available
    * After changing the config: Are the required configmaps/secrets/crds updated?
* changing config options works as expected
    * Names, domains, crd/sa/etc.
    * Eventually just as a dry test? (dumping the yaml & grep)

| Config                                 | Default                                            | Description                         | 
|----------------------------------------|----------------------------------------------------|-------------------------------------|
| `namespaceOverride`                    |                                                    |
| `image.repository`                     | `docker.ausdertechnik.de/uitsmijter/uitsmijter`    |
| `image.tag`                            | `[App Version]`                                    |
| `image.pullPolicy`                     | `Always`                                           |
| `imagePullSecrets[].name`              | `gitlab-auth`                                      |
| `jwtSecret`                            | `vosai0za6iex8AelahGem[...]`                       |
| `redisPassword`                        | `Shohmaz1`                                         |
| `storageClassName`                     | `default-ext4`                                     |
| `installCRD`                           | `true`                                             |
| `installSA`                            | `true`                                             |
| `config.logFormat`                     | `console`                                          | From `console, ndjson`              |
| `config.logLevel`                      | `info`                                             | From `trace, info, error, critical` |
| `config.cookieExpirationInDays`        | `7`                                                |
| `config.tokenExpirationInHours`        | `2`                                                |
| `config.tokenRefreshExpirationInHours` | `720`                                              |
| `config.displayVersion`                | `true`                                             |
| `domains[].domain`                     | `nightly.uitsmijter.io` & `nightly2.uitsmijter.io` |
| `domains[].tlsSecretName`              | `uitsmijter.io`                                    |
| Internally used:                       |
| `nameOverride`                         | `uitsmijter`                                       |
| `fullnameOverride`                     | `[Chart Name]`                                     |
| `serviceAccount.create`                |                                                    |
| `serviceAccount.name`                  | `uitsmijter,default`                               |
| `deploymentNameOverride`               |                                                    |
| `serviceNameOverride`                  |                                                    |

### Tenant / Client

:label: E2E

In k8s the `name` is defined as `metadata.name` and `config` is called `spec`.

### [Tests](playwright/tests)

* Types
    * [Interceptor](playwright/tests/Interceptor)
        * Tenant / Client not found
        * Unauthenticated request -> redirect Login
        * Login
            * Wrong Credentials
            * Success -> Redirect back
        * Authenticated + Valid JWT
            * Are all required field there
        * Eventually test JWT auto refresh
            * With user deletion
        * Logout
    * [OAuth2 Server](playwright/tests/OAuth)
        * Tenant / Client not found
        * Authorization code flow
            * Unauthenticated request -> redirect Login
            * login
                * Wrong Credentials
                * Success -> redirect to page
            * exchange authorization code -> access token & refresh token
            * use access token / decode user data (is it all there?)
            * refresh access token using refresh token -> Refresh token flow
            * explicit logout?
            * test by requesting limited scopes
        * Implicit/Password flow (deprecated)
            * Same as Authorization code flow but without refresh token
            * Not working if not enabled
        * Refresh token flow
            * Get expired access token
            * Use refresh token to get new access token
                * Test what happens if user got deleted
            * Validate the token
        * Ensure endpoints tested:
            * /authorize
            * /token
            * /token/info
        * PKCE enabled / disabled
* (UserBackend-) Providers
    * "Allow all" / "Allow special" mode
    * Check against backend server
    * Returns provided userdata like profile info (IDs, names, email) and roles
    * Use all/some provided methods (unit test?)
* Tenant
    * Handling of multiple tenants
    * Multiple hosts
    * Interceptor enabled / disabled
    * Multiple providers
    * Silent login
    * Resource changed / Deleted / Created
    * Setting a subject
* Client
    * Handling of multiple clients
    * Different scopes
        * subset of scopes
        * no scopes?
    * multiple redirect urls
        * also invalid redirect targets
    * subset of grant types
    * other referrers
    * pkce only
    * wrong client secret
    * Resource changed / Deleted / Created

#### Tenant

| Option                       | Default | Description                              |
|------------------------------|---------|------------------------------------------|
| `name`                       |         | Required                                 |
| `config.hosts[]`             |         | Required                                 |
| `config.interceptor{}`       |         | Optional                                 |
| `config.interceptor.enabled` |         | Required                                 |
| `config.interceptor.domain`  |         | Optional                                 |
| `config.interceptor.cookie`  |         | Optional                                 |
| `config.providers[]`         | `[]`    | Required                                 |
| `config.silent_login`        | `true`  | Optional                                 |
| Internal:                    |
| `ref`                        |         | File by Path or K8S by UUID and revision | 

#### Client

| Option                   | Default                               | Description                                                |
|--------------------------|---------------------------------------|------------------------------------------------------------|
| `name`                   |                                       | Required                                                   |
| `config.ident`           |                                       | Required, UUID                                             |
| `config.tenantname`      |                                       | Required                                                   | 
| `config.redirect_urls[]` |                                       | Required                                                   |
| `config.scopes[]`        |                                       | Optional                                                   |
| `config.referrers[]`     |                                       | Optional                                                   |
| `config.grant_types[]`   | `[authorization_code, refresh_token]` | `authorization_code, refresh_token, password (deprecated)` | 
| `config.isPkceOnly`      | `false`                               | Optional                                                   |
| `config.secret`          |                                       | Optional                                                   |
| Internal:                |
| `ref`                    |                                       | File by Path or K8S by UUID and revision                   |
| `config.tenant`          |                                       | Used tenant                                                |

### Translations

:label: E2E

* All Pages are translatable
    * Including error messages
* Check all pages per language if they load, have useful content and show translations

```
Resources/Translations/
├── de_DE.json
├── en_EN.json
└── pt_PT.json
```

### Views & Assets

:label: E2E

* All templates show content
    * index
    * [login](playwright/tests/Pages/LoginPage.spec.ts)
    * logout
    * error
* Tenant specific templates replace default views
* Assets (images and css) are loaded (even if no tenant can be found)

```
Resources/Views/
└── default
    ├── error.leaf
    ├── index.leaf
    ├── login.leaf
    └── logout.leaf
```
