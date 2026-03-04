import {test, expect} from '@playwright/test';
import {Application} from "../Fixtures/app";
import {loginAuthorizeFormRequest} from "../OAuth/AuthorizeRequests";

const hamAuthUrl = 'https://id.ham.test';
const hamClientId = 'cd7a444a-7aa9-4f27-9305-9e2a9c4d47ee';
const hamRedirectUri = 'https://id.ham.test/callback';
const validUsername = 'test@example.com';

// The Ham tenant provider denies logins when grant_type is 'interceptor'.
// These tests verify that an OAuth login succeeds and an interceptor login is denied.

test.describe('Grant type check in provider', () => {

    test.describe('happy path: authorization_code grant is allowed', () => {
        test.describe.configure({mode: 'serial'});

        const myState = Math.floor(Math.random() * 999999999);

        test('should return an authorization code for a valid OAuth login', async ({page}) => {
            const response = await loginAuthorizeFormRequest(
                page,
                hamAuthUrl,
                {
                    client_id: hamClientId,
                    redirect_uri: hamRedirectUri,
                    response_type: 'code',
                    scope: '',
                    state: '' + myState,
                    username: validUsername,
                }
            );

            expect(response.url()).toContain('code=');
            expect(response.url()).toContain('state=' + myState);
        });
    });

    test.describe('error path: interceptor grant is denied', () => {

        test.beforeEach(async ({page}) => {
            const app = new Application(page)
            test.setTimeout(app.timeout)
            // Navigating to the interceptor-protected page causes Traefik to
            // redirect to the login page with mode=interceptor.
            await app.goto('https://page.ham.test/');
        });

        test('should show the login page when accessing a protected resource', async ({page}) => {
            await expect(page).toHaveTitle(/Login/);
        });

        test('should deny login and show an error when grant type is interceptor', async ({page}) => {
            const app = new Application(page)
            await app.auth.login(validUsername, 'secretPassword');

            await expect(page).toHaveURL(/id\.ham\.test\/login/);
            await expect(page).toHaveTitle(/Login/);
        });

        test('should allow login for the excepted user via interceptor grant', async ({page, browserName}) => {
            test.skip(browserName === 'webkit' || browserName === 'mobile-safari', 'WebKit form submission issue');
            const app = new Application(page)
            await app.auth.login('allow@example.com', 'secretPassword');

            await expect(page).toHaveTitle('A hilarious ham named Hank');
        });
    });
});
