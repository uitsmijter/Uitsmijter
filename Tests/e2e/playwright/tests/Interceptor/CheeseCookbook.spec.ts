import {test, expect, Page} from '@playwright/test';
import {Application} from "../Fixtures/app";

const timeout = 60 / 2 * 1000;

test.describe('Cheese Cookbooks Interceptor', () => {

    test.beforeEach(async ({page}) => {
        const app = new Application(page, timeout)
        test.setTimeout(app.timeout)

        await app.goto('https://cookbooks.example.com/');
    });

    async function fillLoginForm(page: Page) {
        const app = new Application(page, timeout)
        await app.auth.login("hello@example.com", "se*retpassw0rd")
    }

    test.describe('should be protected', () => {
        test('and not showing the Cookbook', async ({page}) => {
            // Expect a title form a login page, not from the secured webpage
            await expect(page).not.toHaveTitle(/Cookbooks/);
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

    test.describe('should not be accessible', () => {
        test('with wrong password', async ({page}) => {
            const app = new Application(page, timeout)
            await app.auth.login("hello@foo.com", "se*retpassw0rd", page)

            await expect(page).toHaveURL("https://login.example.com/login")
            await expect(page).toHaveTitle(/Login/);

            const errorMessage = await page.locator('div[data-error="LOGIN.ERRORS.WRONG_CREDENTIALS"]');
            await expect(errorMessage).toBeVisible();
            await expect(errorMessage).toHaveClass("error");
            await expect(errorMessage).toContainText("incorrect credentials")
            
            await page.waitForLoadState('networkidle');
            expect(await page.screenshot()).toMatchSnapshot();
        });
    });

    test.describe('should be accessible', () => {

        test('after enter correct credentials', async ({page}) => {
            await fillLoginForm(page)
            await expect(page).toHaveURL("https://cookbooks.example.com/")
            await expect(page).toHaveTitle(/Cookbooks/);
        });

        test('and have known elements', async ({page}) => {
            await fillLoginForm(page)

            const headline = await page.locator("h1").first();
            await expect(headline).toContainText("Ingredients for an Uitsmijter");

            const content = await page.content();
            const textIdx = content.indexOf('place a lid on the pan and allow the eggs to steam')
            expect(textIdx).toBeGreaterThan(-1);
        });

        test('and a cookie is present', async ({page}) => {
            await fillLoginForm(page)
            const cookies = await page.context().cookies();
            expect(cookies.length).toBeGreaterThan(0);
            expect(cookies.map(cookie => {
                return cookie.name
            })).toContain("uitsmijter-sso");
            expect(cookies.map(cookie => {
                return cookie.domain
            })).toContain(".example.com");
        });

        test('and the screen is the same', async ({page}) => {
            await fillLoginForm(page)
            await page.waitForLoadState('networkidle');
            expect(await page.screenshot()).toMatchSnapshot();
        });
    });

    test.describe('should be able to log out', () => {
        test('and the screen is the same', async ({page}) => {
            const app = new Application(page, timeout)

            await fillLoginForm(page)
            const logoutButton = await page.locator("a").getByText('logout');
            await expect(logoutButton).toBeVisible()

            await logoutButton.click();
            await app.waitForPage()

            await page.waitForTimeout(5000);

            await page.reload();
            await app.waitForPage()

            // Firefox do not logout
            await expect(page).toHaveTitle(/Login/);
            await page.waitForLoadState('networkidle');
            expect(await page.screenshot()).toMatchSnapshot();

            // check cookie is gone.
            const cookies = await page.context().cookies();
            expect(cookies.map(cookie => {
                return cookie.name
            })).not.toContain("uitsmijter-sso");
        });
    });
});
