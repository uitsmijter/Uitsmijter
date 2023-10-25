import {test, expect} from '@playwright/test';
import {Application} from "../Fixtures/app";
import {
    authorizeApiRequest, decodeJwt,
    getTokenForAuthorisationCode,
    getTokenInfo,
    loginAuthorizeFormRequest
} from "./AuthorizeRequests";

test.describe('Authorization code OAuth flow', () => {

    test.beforeEach(async ({page}) => {
        const app = new Application(page)
        test.setTimeout(app.timeout)
    });

    // https://docs.uitsmijter.io/oauth/flow/
    // ------------------------------------------------------
    // "forTestingPurposesOnly"
    // 143A3135-5DE2-46D4-828F-DDCF20C72060 = cheese-api-insecure

    test.describe('complete lifecycle', () => {

        test.describe('happy path', async () => {

            // All tests in this describe must be executed in series
            test.describe.configure({mode: 'serial'});

            // Flow context
            const myState = Math.floor(Math.random() * 999999999);
            let code: string = null
            let accessToken: string = null
            let refreshToken: string = null

            // General Auth 2 Flow (SPA) - Step 1 - 2
            test('should respond with a login page to the request for an authorization code', async () => {
                const response = await authorizeApiRequest(
                    'https://id.example.com',
                    {
                        response_type: 'code',
                        client_id: '143A3135-5DE2-46D4-828F-DDCF20C72060',
                        client_secret: null,
                        redirect_uri: 'https://api.example.com',
                        scope: '',
                        state: '' + myState
                    }
                );

                await expect(response.headers()['server']).toContain('Uitsmijter');
                await expect(response.status()).toBe(401);

                const content = await response.text();
                await expect(content).toContain('form action="/login"')
                await expect(content).toContain('state=' + myState)
            });

            // General Auth 2 Flow (SPA) - Step 3 - 5
            test('should respond after login with a code for authorization', async ({page}) => {
                const response = await loginAuthorizeFormRequest(
                    page,
                    'https://id.example.com',
                    {
                        client_id: "143A3135-5DE2-46D4-828F-DDCF20C72060",
                        redirect_uri: "https://api.example.com/",
                        response_type: "code",
                        scope: "access",
                        state: "" + myState,
                        username: "cee8Esh5@example.com"
                    }
                );

                await expect(response.status()).toBe(404); // redirect_uri is not known

                expect(response.url()).toContain("state=" + myState)
                expect(response.url()).toContain("code=");
                code = response.url().match(/code=(.+)&/)[1];
                expect(code.length).toBeGreaterThan(0);
            });

            // Should be able to request multiple scopes -> UIT-317
            test(
                'should respond with multible scopes after login with a code for authorization',
                async ({page}) => {
                    const response = await loginAuthorizeFormRequest(
                        page,
                        'https://id.example.com',
                        {
                            client_id: "143A3135-5DE2-46D4-828F-DDCF20C72060",
                            redirect_uri: "https://api.example.com",
                            response_type: "code",
                            scope: "access+write+change",
                            state: "" + myState,
                            username: "cee8Esh5@example.com"
                        }
                    );
                    expect(response.url()).toContain("state=" + myState)
                    expect(response.url()).toContain("code=");
                    code = response.url().match(/code=(.+)&/)[1];
                    expect(code.length).toBeGreaterThan(0);
                }
            );

            test('should respond with a token for a code', async () => {
                // request authorization_code
                const tokenResponse = await getTokenForAuthorisationCode(
                    'https://id.example.com',
                    {
                        "grant_type": "authorization_code",
                        "client_id": "143A3135-5DE2-46D4-828F-DDCF20C72060",
                        "scope": "access",
                        "code": "" + code
                    }
                );

                const jsonResponse = await tokenResponse.json();
                expect(jsonResponse).toHaveProperty('scope')
                expect(jsonResponse).toHaveProperty('access_token')
                expect(jsonResponse).toHaveProperty('refresh_token')
                expect(jsonResponse).toHaveProperty('expires_in')
                expect(jsonResponse.scope).toContain("access")

                accessToken = jsonResponse.access_token;
                refreshToken = jsonResponse.refresh_token;
            });

            // Info
            test('should respond info for a valid token', async () => {
                const tokenInfoResponse = await getTokenInfo(
                    'https://id.example.com',
                    accessToken
                )

                const jsonInfoResponse = await tokenInfoResponse.json();
                expect(jsonInfoResponse).toHaveProperty('name')
                expect(jsonInfoResponse.name).toBe('Test User')
            });

            // refresh
            test('should respond with a new token for a refresh token', async () => {
                // request authorization_code
                const tokenResponse = await getTokenForAuthorisationCode(
                    'https://id.example.com',
                    {
                        "grant_type": "refresh_token",
                        "client_id": "143A3135-5DE2-46D4-828F-DDCF20C72060",
                        "refresh_token": refreshToken
                    },
                    accessToken
                );
                const oldAccessToken = accessToken

                const jsonResponse = await tokenResponse.json();
                expect(jsonResponse).toHaveProperty('scope')
                expect(jsonResponse).toHaveProperty('access_token')
                expect(jsonResponse).toHaveProperty('refresh_token')
                expect(jsonResponse).toHaveProperty('expires_in')

                expect(jsonResponse.access_token).not.toBe(oldAccessToken)
                expect(jsonResponse.refresh_token).not.toBe(refreshToken)

                accessToken = jsonResponse.access_token;
                refreshToken = jsonResponse.refresh_token;

                const oldJwtPayload = decodeJwt(oldAccessToken).payload
                const newJwtPayload = decodeJwt(accessToken).payload

                expect(newJwtPayload.exp).toBeGreaterThan(oldJwtPayload.exp)
            });
        });

        test.describe('check scopes', async () => {
            // All tests in this describe must be executed in series
            test.describe.configure({mode: 'serial'});

            // Flow context
            const myState = Math.floor(Math.random() * 999999999);
            let code: string = null

            test('should respond after login with a code for authorization', async ({page}) => {
                const response = await loginAuthorizeFormRequest(
                    page,
                    'https://id.example.com',
                    {
                        client_id: "143A3135-5DE2-46D4-828F-DDCF20C72060",
                        redirect_uri: "https://api.example.com/",
                        response_type: "code",
                        scope: "access+write+delete",
                        state: "" + myState,
                        username: "cee8Esh5@example.com"
                    }
                );

                await expect(response.status()).toBe(404); // redirect_uri is not known

                expect(response.url()).toContain("state=" + myState)
                expect(response.url()).toContain("code=");
                code = response.url().match(/code=(.+)&/)[1];
                expect(code.length).toBeGreaterThan(0);
            });

            test('should respond with filtered scopes', async () => {
                // request authorization_code
                // allowed are:
                //     - access
                //     - update
                //     - delete
                const tokenResponse = await getTokenForAuthorisationCode(
                    'https://id.example.com',
                    {
                        "grant_type": "authorization_code",
                        "client_id": "143A3135-5DE2-46D4-828F-DDCF20C72060",
                        "scope": "access write delete",
                        "code": "" + code
                    }
                );

                const jsonResponse = await tokenResponse.json();
                expect(jsonResponse).toHaveProperty('scope')

                expect(jsonResponse.scope).toContain('access');
                expect(jsonResponse.scope).toContain('delete');

                expect(jsonResponse.scope).not.toContain('write');
            });
        })

        test.describe('error case', async () => {
            // All tests in this describe must be executed in series
            test.describe.configure({mode: 'serial'});

            // Flow context
            const myState = Math.floor(Math.random() * 999999999);

            // Invalid client
            test('should respond with forbidden when client not found', async ({page}) => {
                const response = await loginAuthorizeFormRequest(
                    page,
                    'https://id.example.com',
                    {
                        client_id: "596de0f2-6b47-4c0e-9460-f7402f4a136d",
                        redirect_uri: "https://api.example.com",
                        response_type: "code",
                        scope: "",
                        state: "" + myState,
                        username: ""
                    }
                );

                expect(response.status()).toEqual(400)
                expect(response.url()).toContain("https://id.example.com/login")
                expect(String(await response.body())).toContain("LOGIN.ERRORS.NO_CLIENT");
            });

            // Invalid credentials
            test('should respond with forbidden after entering invalid credentials', async ({page}) => {
                const response = await loginAuthorizeFormRequest(
                    page,
                    'https://id.example.com',
                    {
                        client_id: "143A3135-5DE2-46D4-828F-DDCF20C72060",
                        redirect_uri: "https://api.example.com",
                        response_type: "code",
                        scope: "",
                        state: "" + myState,
                        username: "not-existing-user"
                    }
                );

                expect(response.status()).toEqual(403)
                expect(response.url()).toContain("https://id.example.com/login")
                expect(String(await response.body())).toContain("LOGIN.ERRORS.WRONG_CREDENTIALS");
            });
        });
    });
})
