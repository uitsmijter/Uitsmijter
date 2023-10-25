import {test, expect} from '@playwright/test';
import {Application} from "../Fixtures/app";
import {
    authorizeFormRequest,
    getTokenForAuthorisationCode,
    getTokenInfo,
    loginAuthorizeFormRequest
} from "./AuthorizeRequests";
import { createCodeChallenge, generateCodeVerifier } from './Pkce';

test.describe('OAuth PKCE', () => {

    test.beforeEach(async ({page}) => {
        const app = new Application(page)
        test.setTimeout(app.timeout)
    });

    // https://docs.uitsmijter.io/oauth/flow/
    // ------------------------------------------------------
    // "forTestingPurposesOnly"
    // b88d44ed-4e8f-4f50-817b-58b86297ccab = cheese-api-pkce

    // Flow context
    const myState = Math.floor(Math.random() * 999999999);

    test.describe('happy path', async () => {
        // All tests in this describe must be executed in series
        test.describe.configure({mode: 'serial'});

        const verifier = generateCodeVerifier()
        const challenge = createCodeChallenge(verifier)
        let code: string = ''
        let accessToken: string = ''
        let refreshToken: string = ''


        test('should respond after login with a code for authorization', async () => {
            const response = await authorizeFormRequest(
                'https://id.example.com',
                {
                    client_id: "b88d44ed-4e8f-4f50-817b-58b86297ccab",
                    redirect_uri: "https://api.example.com",
                    response_type: "code",
                    scope: "",
                    state: "" + myState,
                    code_challenge: challenge,
                    code_challenge_method: 'S256',
                    response_mode: 'query',
                    username: "test@example.com",
                }
            );

            expect(response.url()).toContain("state=" + myState)
            expect(response.url()).toContain("code=");
            code = response.url().match(/code=(.+)&/)[1];
            expect(code.length).toBeGreaterThan(0);
        });

        test('should respond with a token for a code', async () => {
            test.fail() // grant list is nil -> UIT-316
            // request authorization_code
            const tokenResponse = await getTokenForAuthorisationCode(
                'https://id.example.com',
                {
                    "grant_type": "authorization_code",
                    "client_id": "b88d44ed-4e8f-4f50-817b-58b86297ccab",
                    "scope": "",
                    "code": "" + code,
                    "code_verifier": verifier,
                }
            );

            const jsonResponse = await tokenResponse.json();
            expect(jsonResponse).toHaveProperty('scope')
            expect(jsonResponse).toHaveProperty('access_token')
            expect(jsonResponse).toHaveProperty('refresh_token')
            expect(jsonResponse).toHaveProperty('expires_in')

            accessToken = jsonResponse.access_token;
            refreshToken = jsonResponse.refresh_token;
        });

    });

    test('should respond with error if not a pkce request', async ({page}) => {
        const response = await loginAuthorizeFormRequest(
            page,
            'https://id.example.com',
            {
                client_id: "b88d44ed-4e8f-4f50-817b-58b86297ccab",
                redirect_uri: "https://api.example.com",
                response_type: "code",
                scope: "",
                state: "" + myState,
                username: "foo@example.com",
            }
        );

        expect(String(await response.body())).toContain('ERRORS.CLIENT_ONLY_SUPPORTS_PKCE')
    });
})
