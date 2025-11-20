import {test, expect, Page} from '@playwright/test';
import {Application} from "../Fixtures/app";


const timeout = 60 / 2 * 1000;

test.describe('Cheese Goat Interceptor', () => {

    test.beforeEach(async ({page}) => {
        const app = new Application(page, timeout)
        test.setTimeout(app.timeout)

        await page.goto('https://cookbooks.example.com/');
        await app.waitForPage()
    });

    async function fillLoginForm(page: Page, url: string = "") {
        const app = new Application(page, timeout)
        if (url !== "") {
            await page.goto(url);
            await app.waitForPage()
        }
        await app.auth.login("hello@example.com", "se*retpassw0rd")
    }

    test.describe('should be protected', () => {

        test('and not showing the page', async ({page}) => {
            // Expect a title form a login page, not from the secured webpage
            await expect(page).not.toHaveTitle(/Goats/);
            await expect(page).toHaveTitle(/Login/);
        });

        test('and have username field in viewport', async ({page}) => {
            const usernameField = await page.locator("input#username");
            await expect(usernameField).toBeVisible()
        });

        test('and have password field in viewport', async ({page}) => {
            const passwordField = await page.locator("input#password");
            await expect(passwordField).toBeVisible()
        });

        test('and have a submit button', async ({page}) => {
            const submitButton = await page.locator("button#loginButton");
            await expect(submitButton).toBeVisible()
            await expect(submitButton).toContainText("Log In")
        });
    });

    test.describe('should be accessible after login to cookbooks (same cookie domain)', () => {

        test('goat should be accessible after login to cookbooks', async ({page}) => {
            await page.goto('https://cookbooks.example.com/');
            await page.waitForSelector('body', {state: 'attached', timeout: timeout});
            await page.waitForLoadState("networkidle");

            await fillLoginForm(page, 'https://cookbooks.example.com/')


            await page.goto('https://goat.example.com/');
            await page.waitForSelector('body', {state: 'attached', timeout: timeout});
            await page.waitForLoadState("networkidle");

            await expect(page).toHaveURL("https://goat.example.com/")
            await expect(page).toHaveTitle(/Goats/);
        });
    });

});
