import {test, expect} from '@playwright/test';
import {Application} from "../Fixtures/app";

test.describe('Templates', () => {
    let app: Application

    test.beforeEach(async ({page}) => {
        app = new Application(page)
        test.setTimeout(app.timeout);
    });

    test('error not from S3', async ({page}) => {
        let response = await app.goto('https://id.ham.test/login-404?for=https://shop.ham.test/')
        
        // Should be the default 404 page
        expect(response?.status()).toBe(404)
        expect(await page.content()).toContain('class="error-main"')
        expect(await page.content()).not.toContain('data-tenant="ham"')
        await page.waitForLoadState('networkidle');
        expect(await page.screenshot()).toMatchSnapshot();
    });

    test('login loaded from S3', async ({page}) => {
        let response = await app.goto('https://page.ham.test')

        // Should be the S3 login page
        expect(response?.status()).toBe(200)
        expect(await page.content()).toContain('Login')
        expect(await page.content()).toContain('logo-box')
        expect(await page.content()).toContain('data-tenant="ham"')
        await page.waitForLoadState('networkidle');
        expect(await page.screenshot()).toMatchSnapshot();
    });

    test('logout loaded from S3', async ({page, browserName}) => {
        test.skip(browserName === 'webkit' || browserName === 'mobile-safari', 'WebKit form submission issue');

        let response = await app.goto('https://page.ham.test')
        await app.auth.login('allow@example.com', 'test')

        // logout
        const logoutLink = await page.locator('a').getByText('logout')
        await logoutLink.click();
        await app.waitForPage();

        // The logout page carries `<meta http-equiv="refresh" content="2;URL=/logout/finalize…">`,
        // so it navigates itself away after 2s. On slower emulated devices (e.g. mobile-pixel) the
        // assertions and screenshot below can cross that boundary and observe the wrong page, which
        // makes this test flaky. Cancel the pending finalize navigation so the transient logout page
        // stays put. Registered after the click so it only affects the meta-refresh, not the click.
        await page.route('**/logout/finalize*', route => route.abort());

        // Read the rendered page once so every assertion observes the same point in time.
        const html = await page.content()

        // Should be the S3 logout page
        expect(response?.status()).toBe(200)
        expect(html).toContain('Logout')
        expect(html).toContain('in progress')
        expect(html).toContain('logout-box')
        expect(html).toContain('data-tenant="ham"')
        expect(await page.screenshot()).toMatchSnapshot();
    });

});
