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
        expect(await page.screenshot()).toMatchSnapshot();
    });

    test('login loaded from S3', async ({page}) => {
        let response = await app.goto('https://page.ham.test')

        // Should be the S3 login page
        expect(response?.status()).toBe(200)
        expect(await page.content()).toContain('Login')
        expect(await page.content()).toContain('logo-box')
        expect(await page.content()).toContain('data-tenant="ham"')
        expect(await page.screenshot()).toMatchSnapshot();
    });

    test('logout loaded from S3', async ({page}) => {
        let response = await app.goto('https://page.ham.test')
        await app.auth.login('test@example.com', 'test')

        // logout
        const logoutLink = await page.locator('a').getByText('logout')
        await logoutLink.click();
        await app.waitForPage();

        // Should be the S3 logout page
        expect(response?.status()).toBe(200)
        expect(await page.content()).toContain('Logout')
        expect(await page.content()).toContain('in progress')
        expect(await page.content()).toContain('logout-box')
        expect(await page.content()).toContain('data-tenant="ham"')
        expect(await page.screenshot()).toMatchSnapshot();
    });

});
