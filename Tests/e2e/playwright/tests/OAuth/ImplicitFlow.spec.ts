import {test, expect} from '@playwright/test';
import {Application} from "../Fixtures/app";
import {
    getTokenForAuthorisationCode,
    getTokenInfo,
} from "./AuthorizeRequests";

test.describe('Password/Implicit OAuth mode', () => {

    test.beforeEach(async ({page}) => {
        const app = new Application(page)
        test.setTimeout(app.timeout)
    });

    // https://docs.uitsmijter.io/oauth/flow/
    // https://docs.uitsmijter.io/oauth/granttypes/#password
    // ------------------------------------------------------
    // "forTestingPurposesOnly"
    // e92b4a0b-d1d7-4d55-b2e3-dc570faca745 = cheese-website
    // d9c48a1b-46bd-49d8-9305-08b8e380a69e = cheese-api

    test.describe('complete lifecycle', () => {

        test.describe('happy path', async () => {

            // All tests in this describe must be executed in series
            test.describe.configure({mode: 'serial'});

            // Flow context
            let accessToken: string = null

            test('should respond with a token on authentication', async () => {
                // request authorization_code
                const tokenResponse = await getTokenForAuthorisationCode(
                    'https://id.example.com',
                    {
                        "grant_type": "password",
                        "client_id": "e92b4a0b-d1d7-4d55-b2e3-dc570faca745",
                        "client_secret": "luaTha1qu019ohc13qu3ze1yuo5MumEl0hQuoE9bon",
                        "scope": "read learn",
                        "username": "testuser@example.com",
                        "password": "Tes1Pas5w0r1",
                    }
                );

                const jsonResponse = await tokenResponse.json();
                expect(jsonResponse).toHaveProperty('access_token')
                expect(jsonResponse).toHaveProperty('expires_in')
                expect(jsonResponse).toHaveProperty('scope')
                expect(jsonResponse).toHaveProperty('token_type')

                accessToken = jsonResponse.access_token;
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
        });

        test.describe('error case', async () => {
            test('should respond with error when not enabled', async () => {
                // request authorization_code with password flow
                const tokenResponse = await getTokenForAuthorisationCode(
                    'https://id.example.com',
                    {
                        "grant_type": "password",
                        "client_id": "d9c48a1b-46bd-49d8-9305-08b8e380a69e",
                        "client_secret": "luaTha1qu019ohc13qu3ze1yuo5MumEl0hQuoE9bon",
                        "scope": "read learn",
                        "username": "testuser@example.com",
                        "password": "Tes1Pas5w0r1",
                    }
                );

                expect(tokenResponse.status()).toBe(400)

                const jsonResponse = await tokenResponse.json()
                expect(jsonResponse).toHaveProperty('status')
                expect(jsonResponse.status).toBe(400)
                expect(jsonResponse).toHaveProperty('error')
                expect(jsonResponse.error).toBe(true)
                expect(jsonResponse).toHaveProperty('reason')
                expect(jsonResponse.reason).toBe('ERROR.UNSUPPORTED_GRANT_TYPE')
            });

            test('should respond with unauthorized when using wrong client secret', async () => {
                // request authorization_code with wrong client secret
                const tokenResponse = await getTokenForAuthorisationCode(
                    'https://id.example.com',
                    {
                        "grant_type": "password",
                        "client_id": "e92b4a0b-d1d7-4d55-b2e3-dc570faca745",
                        "client_secret": "wrongClientSecret",
                        "scope": "",
                        "username": "",
                        "password": "",
                    }
                );

                expect(tokenResponse.status()).toBe(401)

                const jsonResponse = await tokenResponse.json()
                expect(jsonResponse).toHaveProperty('status')
                expect(jsonResponse.status).toBe(401)
                expect(jsonResponse).toHaveProperty('error')
                expect(jsonResponse.error).toBe(true)
                expect(jsonResponse).toHaveProperty('reason')
                expect(jsonResponse.reason).toBe('ERROR.WRONG_CLIENT_SECRET')
            });

            test('should respond with unauthorized when using wrong credentials', async () => {
                // request authorization_code with wrong credentials
                const tokenResponse = await getTokenForAuthorisationCode(
                    'https://id.example.com',
                    {
                        "grant_type": "password",
                        "client_id": "e92b4a0b-d1d7-4d55-b2e3-dc570faca745",
                        "client_secret": "luaTha1qu019ohc13qu3ze1yuo5MumEl0hQuoE9bon",
                        "scope": "read learn",
                        "username": "not-existing-user",
                        "password": "test",
                    }
                );

                expect(tokenResponse.status()).toBe(403)

                const jsonResponse = await tokenResponse.json()
                expect(jsonResponse).toHaveProperty('status')
                expect(jsonResponse.status).toBe(403)
                expect(jsonResponse).toHaveProperty('error')
                expect(jsonResponse.error).toBe(true)
                expect(jsonResponse).toHaveProperty('reason')
                expect(jsonResponse.reason).toBe('ERRORS.WRONG_CREDENTIALS')
            });
        });
    });
})
