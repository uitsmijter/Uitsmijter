//! # Device Grant Demo
//!
//! A small, interactive command-line client that runs the full
//! **OAuth 2.0 Device Authorization Grant** (RFC 8628) against a Uitsmijter
//! OIDC server.
//!
//! The device flow is designed for input-constrained clients (CLIs, smart TVs,
//! IoT devices) that cannot easily open a browser:
//!
//! 1. The device asks the server for a `device_code` + a short `user_code`.
//! 2. The device tells the user to open a URL on a *second* device (phone,
//!    laptop) and enter the `user_code`.
//! 3. Meanwhile the device *polls* the token endpoint until the user has
//!    approved (or denied) the request, then receives the tokens.
//!
//! We use the [`oauth2`] crate, which implements this flow — including the
//! polling loop with `interval` / `slow_down` handling — so we don't reimplement
//! the protocol by hand. This relies on the server being RFC 8628 compliant
//! (standard `grant_type` URN and `{"error": "..."}` token error responses).

use std::io::{self, Write};
use std::time::Duration;

use clap::Parser;
use oauth2::basic::BasicClient;
use oauth2::{
    ClientId, ClientSecret, DeviceAuthorizationUrl, Scope, StandardDeviceAuthorizationResponse,
    TokenResponse, TokenUrl,
};
use serde::Deserialize;

/// Fallback endpoint paths, used when the server's discovery document does not
/// advertise them. These match Uitsmijter's route registration.
const DEFAULT_DEVICE_PATH: &str = "/oauth/device_authorization";
const DEFAULT_TOKEN_PATH: &str = "/token";

/// Command-line arguments. Every value can be supplied via a flag or an
/// environment variable; anything left out is asked for interactively (unless
/// `--non-interactive` is set, in which case a missing required value is an error).
#[derive(Debug, Parser)]
#[command(
    name = "device-grant-demo",
    about = "Run the OAuth 2.0 Device Authorization Grant (RFC 8628) against a Uitsmijter OIDC server."
)]
struct Args {
    /// OIDC server base URL, e.g. https://login.littleletter.de
    #[arg(short, long, env = "DEVICE_DEMO_SERVER")]
    server: Option<String>,

    /// OAuth client ID.
    #[arg(short, long, env = "DEVICE_DEMO_CLIENT_ID")]
    client_id: Option<String>,

    /// Requested scope (defaults to "openid profile").
    #[arg(long, env = "DEVICE_DEMO_SCOPE")]
    scope: Option<String>,

    /// Client secret for confidential clients (omit for public clients).
    #[arg(long, env = "DEVICE_DEMO_CLIENT_SECRET")]
    client_secret: Option<String>,

    /// Accept invalid TLS certificates (for local self-signed servers).
    #[arg(short = 'k', long, env = "DEVICE_DEMO_INSECURE")]
    insecure: bool,

    /// Never prompt: use flags/env/defaults only, and fail if a required value is missing.
    #[arg(short = 'y', long)]
    non_interactive: bool,
}

/// The subset of the OIDC discovery document we care about.
#[derive(Debug, Deserialize)]
struct DiscoveryDocument {
    device_authorization_endpoint: Option<String>,
    token_endpoint: Option<String>,
}

fn main() {
    if let Err(err) = run() {
        eprintln!("\n❌ Error: {err}");
        std::process::exit(1);
    }
}

fn run() -> Result<(), Box<dyn std::error::Error>> {
    // Parse flags/env first so `--help`/`--version` exit cleanly.
    let args = Args::parse();
    let interactive = !args.non_interactive;

    println!("=== OAuth 2.0 Device Authorization Grant demo (RFC 8628) ===\n");

    // --- 0. Collect inputs (flag/env → prompt → default) -------------------
    let server = resolve(args.server, "OIDC server base URL (e.g. http://localhost:8080)", interactive)?;
    let server = server.trim_end_matches('/').to_string();
    let client_id = resolve(args.client_id, "Client ID", interactive)?;

    let scope = match args.scope {
        Some(scope) => scope,
        None if interactive => {
            let typed = prompt("Scope [openid profile]")?;
            if typed.is_empty() { "openid profile".to_string() } else { typed }
        }
        None => "openid profile".to_string(),
    };

    let client_secret = match args.client_secret {
        Some(secret) => secret,
        None if interactive => prompt("Client secret (leave empty for public clients)")?,
        None => String::new(),
    };

    let insecure = if args.insecure {
        true
    } else if interactive {
        prompt_yes_no("Accept invalid TLS certificates (for local self-signed servers)?")?
    } else {
        false
    };

    // The HTTP client oauth2 drives. Redirects MUST be disabled for OAuth
    // security (the crate documents this). We reuse it for discovery too.
    let http_client = reqwest::blocking::ClientBuilder::new()
        .redirect(reqwest::redirect::Policy::none())
        .danger_accept_invalid_certs(insecure)
        .timeout(Duration::from_secs(30))
        .build()?;

    // --- 1. Discover the endpoints -----------------------------------------
    let (device_endpoint, token_endpoint) = discover_endpoints(&http_client, &server);
    println!("\nUsing endpoints:");
    println!("  device_authorization_endpoint: {device_endpoint}");
    println!("  token_endpoint:                {token_endpoint}\n");

    // --- 2. Configure the oauth2 client ------------------------------------
    let mut client = BasicClient::new(ClientId::new(client_id))
        .set_token_uri(TokenUrl::new(token_endpoint)?)
        .set_device_authorization_url(DeviceAuthorizationUrl::new(device_endpoint)?);
    if !client_secret.is_empty() {
        client = client.set_client_secret(ClientSecret::new(client_secret));
    }

    // --- 3. Request a device + user code -----------------------------------
    let mut device_request = client.exchange_device_code();
    for scope in scope.split_whitespace() {
        device_request = device_request.add_scope(Scope::new(scope.to_string()));
    }
    let details: StandardDeviceAuthorizationResponse = device_request.request(&http_client)?;

    // --- 4. Tell the user what to do ---------------------------------------
    println!("────────────────────────────────────────────────────────");
    println!(" 1. On another device, open:");
    println!("      {}", details.verification_uri());
    println!(" 2. Enter this code:");
    println!("      {}", details.user_code().secret());
    if let Some(complete) = details.verification_uri_complete() {
        println!("\n    (Shortcut with the code pre-filled: {})", complete.secret());
    }
    println!("────────────────────────────────────────────────────────\n");
    println!("Waiting for you to approve the request (Ctrl-C to abort)…");

    // --- 5. Poll for the token ---------------------------------------------
    // oauth2 runs the whole RFC 8628 polling loop for us: it honours the
    // server's `interval`, backs off on `slow_down`, keeps going on
    // `authorization_pending`, and returns on success / denial / expiry.
    let token = client
        .exchange_device_access_token(&details)
        .request(&http_client, std::thread::sleep, None)?;

    // --- 6. Done -----------------------------------------------------------
    println!("\n✅ Authorization successful!\n");
    println!("  token_type:    {:?}", token.token_type());
    if let Some(scopes) = token.scopes() {
        let joined = scopes.iter().map(|s| s.as_str()).collect::<Vec<_>>().join(" ");
        println!("  scope:         {joined}");
    }
    if let Some(expires_in) = token.expires_in() {
        println!("  expires_in:    {}s", expires_in.as_secs());
    }
    println!("  access_token:  {}", token.access_token().secret());
    if let Some(refresh) = token.refresh_token() {
        println!("  refresh_token: {}", refresh.secret());
    }

    Ok(())
}

/// Fetch `<server>/.well-known/openid-configuration` and pull the device and
/// token endpoints out of it, falling back to Uitsmijter's default paths.
fn discover_endpoints(http: &reqwest::blocking::Client, server: &str) -> (String, String) {
    let device_fallback = format!("{server}{DEFAULT_DEVICE_PATH}");
    let token_fallback = format!("{server}{DEFAULT_TOKEN_PATH}");

    let url = format!("{server}/.well-known/openid-configuration");
    match http.get(&url).send().and_then(|r| r.error_for_status()) {
        Ok(resp) => match resp.json::<DiscoveryDocument>() {
            Ok(doc) => (
                doc.device_authorization_endpoint.unwrap_or(device_fallback),
                doc.token_endpoint.unwrap_or(token_fallback),
            ),
            Err(_) => {
                println!("(discovery document could not be parsed — using default paths)");
                (device_fallback, token_fallback)
            }
        },
        Err(_) => {
            println!("(no discovery document found — using default paths)");
            (device_fallback, token_fallback)
        }
    }
}

/// Resolve a required value: use the one from the flag/env if present,
/// otherwise prompt for it — or fail if we are running non-interactively.
fn resolve(
    value: Option<String>,
    message: &str,
    interactive: bool,
) -> Result<String, Box<dyn std::error::Error>> {
    match value {
        Some(value) => Ok(value),
        None if interactive => Ok(prompt(message)?),
        None => Err(format!(
            "missing required value: \"{message}\" — pass it as a flag/env var or drop --non-interactive"
        )
        .into()),
    }
}

/// Print a prompt and read one trimmed line from stdin.
fn prompt(message: &str) -> io::Result<String> {
    print!("{message}: ");
    io::stdout().flush()?;
    let mut input = String::new();
    io::stdin().read_line(&mut input)?;
    Ok(input.trim().to_string())
}

/// Prompt for a yes/no answer. Defaults to `no` on empty input.
fn prompt_yes_no(message: &str) -> io::Result<bool> {
    let answer = prompt(&format!("{message} [y/N]"))?;
    Ok(matches!(answer.to_lowercase().as_str(), "y" | "yes"))
}
