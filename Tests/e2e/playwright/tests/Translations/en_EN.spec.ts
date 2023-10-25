import {test, expect} from '@playwright/test';
import {Application} from "../Fixtures/app";
import {Authentication} from "../Fixtures/authentication";

test.describe('Languages - EN', () => {

    test.use({
        locale: 'en-EN',
        timezoneId: 'Europe/London',
    });

    test.beforeEach(async ({page}) => {
        const app = new Application(page)
        test.setTimeout(app.timeout)
    })

    test('login translated', async ({page}) => {
        const app = new Application(page)
        await page.goto('https://uitsmijter.localhost/login?for=//uitsmijter.localhost');
        await app.waitForPage();

        const field = await page.locator("input#username");
        await expect(field).toHaveAttribute("placeholder", "Username")
    });

    test('error messages translated', async ({page}) => {
        const app = new Application(page)
        await page.goto('https://login.example.com/login?for=//cookbooks.example.com');
        await app.waitForPage();

        await app.auth.login("test", "testing")

        const errorMessage = await page.locator('div[data-error="LOGIN.ERRORS.WRONG_CREDENTIALS"]');
        await expect(errorMessage).toContainText("due to incorrect credentials");
    });

    test('logout translated', async ({page}) => {
        const app = new Application(page)
        await page.goto('https://uitsmijter.localhost/logout?post_logout_redirect_uri=https://uitsmijter.localhost&mode=interceptor');
        await app.waitForPage();

        const field = await page.locator(".logout p");
        await expect(field).toContainText("in progress.")
    });

    test('error translated', async ({page}) => {
        const app = new Application(page)
        await page.goto('https://uitsmijter.localhost/pageNotFound');
        await app.waitForPage();

        const field = await page.locator(".error-headline h1");
        await expect(field).toContainText("Oops, something went wrong");
    });
});
