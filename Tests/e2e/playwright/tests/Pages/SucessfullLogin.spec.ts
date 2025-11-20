import {test, expect} from '@playwright/test';
import {Application} from "../Fixtures/app";

test.describe('OAuth - login', () => {

    test.beforeEach(async ({page}) => {
        const app = new Application(page)
        test.setTimeout(app.timeout);
    });

    test('redirect successful', async ({page}) => {
        const app = new Application(page)
        await app.goto('https://cookbooks.example.com')
        await expect(page).toHaveURL("https://login.example.com/login?for=https://cookbooks.example.com/&mode=interceptor")
        await expect(page).toHaveTitle(/Login/);
    });

    test('succeeds', async ({page}) => {
        const app = new Application(page)
        await app.goto('https://cookbooks.example.com')

        await app.auth.login("test@example.com", "S3cReTpa55W0rd")

        await expect(page).toHaveURL("https://cookbooks.example.com/")
        await expect(page).toHaveTitle(/Cookbooks/);

        const body = await page.locator("body");
        await expect(body).toContainText("2 large eggs")
    });
});
