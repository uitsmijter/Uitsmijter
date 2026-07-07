import {test, expect} from '@playwright/test';
import {Application} from "../Fixtures/app";
import {
    getTokenForAuthorisationCode,
    getTokenInfo,
    loginAuthorizeFormRequest
} from "./AuthorizeRequests";

// Client `cheese-secret-client` is dedicated to client_secret validation
// tests (see Deployment/e2e/applications/Cheese/04-clients.yaml). It has a
// secret and allows the password, authorization_code and refresh_token
// grants — useful for exercising client_secret enforcement on every grant
// type that supports it. The password grant intentionally does not issue a
// refresh_token (see TokenController+TokenGrantTypeRequestHandler.swift), so
// the password happy path only asserts on the access_token.
const authUrl = 'https://id.example.com';
const clientId = '7b1c9e63-2f8a-4d11-9f3e-5a8c2d4b6e90';
const clientSecret = 'Phai0ohG7zaJ2eech4ohch5ouV9aiwoo3ueRoongei';
const redirectUri = 'https://api.example.com/';
const username = 'cee8Esh5@example.com';
const password = 'secretPassword';

test.describe('client_secret validation', () => {

    test.beforeEach(async ({page}) => {
        const app = new Application(page)
        test.setTimeout(app.timeout)
    });

    test.describe('password grant on /token', () => {
        test.describe.configure({mode: 'serial'});

        let accessToken: string = null

        test('issues a token when the correct client_secret is provided', async () => {
            const tokenResponse = await getTokenForAuthorisationCode(
                authUrl,
                {
                    "grant_type": "password",
                    "client_id": clientId,
                    "client_secret": clientSecret,
                    "scope": "access",
                    "username": username,
                    "password": password,
                }
            );

            expect(tokenResponse.status()).toBe(200);

            const jsonResponse = await tokenResponse.json();
            expect(jsonResponse).toHaveProperty('access_token')
            expect(jsonResponse).toHaveProperty('expires_in')
            expect(jsonResponse).toHaveProperty('token_type')
            expect(jsonResponse.scope).toContain('access')

            accessToken = jsonResponse.access_token;
        });

        test('accepts the issued access token on the userinfo endpoint', async () => {
            const tokenInfoResponse = await getTokenInfo(authUrl, accessToken);
            expect(tokenInfoResponse.status()).toBe(200);

            const jsonResponse = await tokenInfoResponse.json();
            expect(jsonResponse).toHaveProperty('name')
        });

        test('rejects the request when client_secret is missing', async () => {
            const tokenResponse = await getTokenForAuthorisationCode(
                authUrl,
                {
                    "grant_type": "password",
                    "client_id": clientId,
                    "scope": "access",
                    "username": username,
                    "password": password,
                }
            );

            expect(tokenResponse.status()).toBe(401);
        });

        test('rejects the request when client_secret is wrong', async () => {
            const tokenResponse = await getTokenForAuthorisationCode(
                authUrl,
                {
                    "grant_type": "password",
                    "client_id": clientId,
                    "client_secret": "this-is-not-the-secret",
                    "scope": "access",
                    "username": username,
                    "password": password,
                }
            );

            expect(tokenResponse.status()).toBe(401);
        });
    });

    test.describe('authorization_code grant', () => {
        test.describe.configure({mode: 'serial'});

        const myState = Math.floor(Math.random() * 999999999);
        let code: string = null
        let accessToken: string = null
        let refreshToken: string = null

        // RFC 6749 §4.1.1: the authorization endpoint must not require the client
        // secret — it is only identified by client_id. The secret is enforced on the
        // token request below.
        test('issues a code from /authorize WITHOUT a client_secret', async ({page}) => {
            const response = await loginAuthorizeFormRequest(
                page,
                authUrl,
                {
                    client_id: clientId,
                    redirect_uri: redirectUri,
                    response_type: "code",
                    scope: "access",
                    state: "" + myState,
                    username: username
                }
            );

            expect(response.url()).toContain("state=" + myState)
            expect(response.url()).toContain("code=");
            code = response.url().match(/code=(.+)&/)[1];
            expect(code.length).toBeGreaterThan(0);
        });

        test('exchanges the code for a token when the correct client_secret is provided on /token', async () => {
            const tokenResponse = await getTokenForAuthorisationCode(
                authUrl,
                {
                    "grant_type": "authorization_code",
                    "client_id": clientId,
                    "client_secret": clientSecret,
                    "scope": "access",
                    "code": "" + code,
                }
            );

            expect(tokenResponse.status()).toBe(200);

            const jsonResponse = await tokenResponse.json();
            expect(jsonResponse).toHaveProperty('access_token')
            expect(jsonResponse).toHaveProperty('refresh_token')
            expect(jsonResponse).toHaveProperty('expires_in')
            expect(jsonResponse.scope).toContain('access')

            accessToken = jsonResponse.access_token;
            refreshToken = jsonResponse.refresh_token;
        });

        test('refreshes the token when the correct client_secret is provided on /token', async () => {
            const tokenResponse = await getTokenForAuthorisationCode(
                authUrl,
                {
                    "grant_type": "refresh_token",
                    "client_id": clientId,
                    "client_secret": clientSecret,
                    "refresh_token": refreshToken,
                },
                accessToken
            );

            expect(tokenResponse.status()).toBe(200);

            const jsonResponse = await tokenResponse.json();
            expect(jsonResponse).toHaveProperty('access_token')
            expect(jsonResponse).toHaveProperty('refresh_token')
            expect(jsonResponse.access_token).not.toBe(accessToken)
        });
    });

    test.describe('authorization_code grant - error cases', () => {
        test.describe.configure({mode: 'serial'});

        const myState = Math.floor(Math.random() * 999999999);
        let code: string = null

        test('returns a code so the token-exchange error cases have something to send', async ({page}) => {
            const response = await loginAuthorizeFormRequest(
                page,
                authUrl,
                {
                    client_id: clientId,
                    redirect_uri: redirectUri,
                    response_type: "code",
                    scope: "access",
                    state: "" + myState,
                    username: username
                }
            );

            expect(response.url()).toContain("code=");
            code = response.url().match(/code=(.+)&/)[1];
            expect(code.length).toBeGreaterThan(0);
        });

        test('rejects the token exchange when client_secret is missing', async () => {
            const tokenResponse = await getTokenForAuthorisationCode(
                authUrl,
                {
                    "grant_type": "authorization_code",
                    "client_id": clientId,
                    "scope": "access",
                    "code": "" + code,
                }
            );

            expect(tokenResponse.status()).toBe(401);
        });

        test('rejects the token exchange when client_secret is wrong', async () => {
            const tokenResponse = await getTokenForAuthorisationCode(
                authUrl,
                {
                    "grant_type": "authorization_code",
                    "client_id": clientId,
                    "client_secret": "this-is-not-the-secret",
                    "scope": "access",
                    "code": "" + code,
                }
            );

            expect(tokenResponse.status()).toBe(401);
        });
    });
});
