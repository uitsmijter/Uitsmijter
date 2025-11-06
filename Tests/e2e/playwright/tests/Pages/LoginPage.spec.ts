import {test, expect} from '@playwright/test';
import { Application } from '../Fixtures/app';

const timeout = 60 / 2 * 1000;

test.describe('OAuth - Default Login Page', () => {
    test.beforeEach(async ({page}) => {
        const app = new Application(page, timeout)
        test.setTimeout(app.timeout)

        await app.goto('https://uitsmijter.localhost/');
        await page.waitForSelector('div.login-box', {state: 'attached', timeout: timeout});
    });

    /// META-Elements
    test('has title', async ({page}) => {
        // Expect a title "to contain" a substring.
        await expect(page).toHaveTitle(/Login/);
    });

    /// Footer-Elements
    test.describe('has footer element', async () => {
        test('imprint', async ({page}) => {
            const element = page.locator('footer a[data-type="imprint"]');
            await expect(element).toContainText('Impressum');
            await expect(element).toHaveAttribute('href', 'https://test.localhost/imprint')
        })

        test('privacy policy', async ({page}) => {
            const element = page.locator('footer a[data-type="privacy"]');
            await expect(element).toContainText('Datenschutz');
            await expect(element).toHaveAttribute('href', 'https://test.localhost/privacy')
        })

        test('registration', async ({page}) => {
            const element = page.locator('footer a[data-type="register"]');
            await expect(element).toContainText('Registrieren');
            await expect(element).toHaveAttribute('href', 'https://test.localhost/register')
        })
    });

    /// Element Texts
    test.describe('has expected elements', () => {
        test.describe('for language en_EN', () => {
            test.use({
                locale: 'en-EN',
                timezoneId: 'Europe/London',
            });

            test('and have username field placeholder', async ({page}) => {
                const field = await page.locator("input#username");
                await expect(field).toHaveAttribute("placeholder", "Username")
            });
            test('and have password field placeholder', async ({page}) => {
                const field = await page.locator("input#password");
                await expect(field).toHaveAttribute("placeholder", "Password")
            });
        });
    });

    // VRT
    test.describe('compared to expected screenshot', () => {
        test.describe('for language en_EN', () => {
            test.use({
                locale: 'en-EN',
                timezoneId: 'Europe/London',
            });
            test('vrt', async ({page}) => {
                expect(await page.screenshot()).toMatchSnapshot();
            });
        });
        test.describe('for language de_DE', () => {
            test.use({
                locale: 'de-DE',
                timezoneId: 'Europe/Berlin',
            });
            test('vrt', async ({page}) => {
                await page.waitForLoadState('networkidle');
                expect(await page.screenshot()).toMatchSnapshot();
            });
        });
    });
});
