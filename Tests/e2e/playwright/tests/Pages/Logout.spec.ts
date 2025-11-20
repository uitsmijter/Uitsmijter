import {test, expect} from '@playwright/test';
import {Application} from "../Fixtures/app";

test.describe('OAuth - logout', () => {

    test.beforeEach(async ({page}) => {
        const app = new Application(page)
        test.setTimeout(app.timeout);

        await app.goto('https://login.example.com/login?for=//cookbooks.example.com')
        await app.auth.login("test@example.com", "S3cReTpa55W0rd")

        await app.goto('https://login.example.com/logout?post_logout_redirect_uri=//cookbooks.example.com')
    });

    test('succeeds', async ({page}, testInfo) => {
        // Wait for page to be login after redirect
        await page.waitForURL(/.*\/login.*/, {timeout: 5 * 1000});

        // Should be redirected back to login page
        await expect(page).toHaveURL("https://login.example.com/login?for=https://cookbooks.example.com/&mode=interceptor")
        await expect(page).toHaveTitle(/Login/);

        // check that cookie got removed
        const cookies = await page.context().cookies();
        expect(cookies.map(cookie => cookie.name)).not.toContain("uitsmijter-sso");
    });

    /// Footer-Elements
    test.describe('has footer element', async () => {
        test('imprint', async ({page}) => {
            const element = page.locator('footer a[data-type="imprint"]');
            await expect(element).toContainText('Impressum');
            await expect(element).toHaveAttribute('href', 'https://example.com/imprint')
        })

        test('privacy policy', async ({page}) => {
            const element = page.locator('footer a[data-type="privacy"]');
            await expect(element).toContainText('Datenschutz');
            await expect(element).toHaveAttribute('href', 'https://example.com/privacy')
        })

        test('registration', async ({page}) => {
            const element = page.locator('footer a[data-type="register"]');
            await expect(element).toContainText('Registrieren');
            await expect(element).toHaveAttribute('href', 'https://example.com/register')
        })
    });
});
