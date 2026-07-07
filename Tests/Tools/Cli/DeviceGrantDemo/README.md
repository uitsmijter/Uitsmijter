# Device Grant Demo

A tiny interactive Rust CLI that performs the full
[OAuth 2.0 Device Authorization Grant (RFC 8628)](https://datatracker.ietf.org/doc/html/rfc8628)
against a Uitsmijter OIDC server.

It exists to demonstrate — and manually test — the device grant introduced in
Uitsmijter `ce-0.11.0`. It is built on the standard [`oauth2`](https://crates.io/crates/oauth2)
crate, so it doubles as a conformance check: if this client works, a stock
OAuth2 device-flow client works.

## What it does

1. Asks for the OIDC server URL, a client ID, scope, and (optionally) a client secret.
2. Discovers the endpoints from `<server>/.well-known/openid-configuration`
   (falling back to `/oauth/device_authorization` and `/token`).
3. Requests a `device_code` + `user_code` via `oauth2`.
4. Prints the verification URL and user code for you to approve on another device.
5. Lets `oauth2` poll the token endpoint, which handles `interval`, `slow_down`,
   `authorization_pending`, and `access_denied` per RFC 8628.
6. Prints the resulting access/refresh tokens.

## Requirements

- A Rust toolchain (`cargo`). Install via <https://rustup.rs>.
- A Uitsmijter client that is allowed to use the device grant, i.e. its config
  lists `device_code` in `grant_types`. (`device_grant_config` is optional —
  the server falls back to sensible defaults when it is omitted.)
- A **RFC 8628-compliant** server: it must accept the
  `urn:ietf:params:oauth:grant-type:device_code` grant type and return standard
  `{"error": "..."}` token errors. Uitsmijter is compliant from `ce-0.11.0`.

## Run

### Interactive

```bash
cd Tests/Tools/Cli/DeviceGrantDemo
cargo run
```

Then follow the prompts, for example:

```
OIDC server base URL (e.g. http://localhost:8080): https://login.example.localhost
Client ID: 9095A4F2-35B2-48B1-A325-309CA324B97E
Scope [openid profile]:
Client secret (leave empty for public clients):
Accept invalid TLS certificates (for local self-signed servers)? [y/N]: y
```

### With parameters (non-interactive)

Every input can be passed as a flag; anything you omit is still prompted for —
unless you add `--non-interactive` (`-y`), which makes missing required values an
error instead. Run `cargo run -- --help` for the full list.

```bash
cargo run -- \
  --server https://login.littleletter.de \
  --client-id 249C1059-1181-4666-9D36-8C5F3D3D8E7C \
  --scope "openid access" \
  --insecure \
  --non-interactive
```

Each flag also has an environment-variable fallback, handy for CI or shell profiles:

```bash
export DEVICE_DEMO_SERVER=https://login.littleletter.de
export DEVICE_DEMO_CLIENT_ID=249C1059-1181-4666-9D36-8C5F3D3D8E7C
export DEVICE_DEMO_SCOPE="openid access"
export DEVICE_DEMO_INSECURE=1
cargo run -- --non-interactive
```

| Flag | Env var | Notes |
|------|---------|-------|
| `-s, --server` | `DEVICE_DEMO_SERVER` | Required |
| `-c, --client-id` | `DEVICE_DEMO_CLIENT_ID` | Required |
| `--scope` | `DEVICE_DEMO_SCOPE` | Defaults to `openid profile` |
| `--client-secret` | `DEVICE_DEMO_CLIENT_SECRET` | Omit for public clients |
| `-k, --insecure` | `DEVICE_DEMO_INSECURE` | Accept self-signed TLS |
| `-y, --non-interactive` | — | Never prompt; error on missing required value |

> **Note:** The device grant is meant for input-constrained clients, so this
> tool never asks for the user's password — you authenticate in a browser at the
> verification URL, exactly as a smart TV or CLI login would.

## Why the `oauth2` crate

Because the device grant is a *standard*, the client should be too. The `oauth2`
crate implements the RFC 8628 flow — including the polling loop — so there is no
bespoke protocol code to maintain, and running it validates the server against a
real, standards-conformant client.

This only works because Uitsmijter is RFC 8628-compliant from `ce-0.11.0`. Older
builds returned a non-standard `grant_type` and Vapor-style error bodies
(`{"error": true, "reason": "ERRORS.…"}` plus HTTP 429 for `slow_down`), which a
stock OAuth2 library cannot interpret. If you point this at such a server, the
polling step will fail.
