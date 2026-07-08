import {test, expect} from '@playwright/test';
import {Application} from '../Fixtures/app';

// Device Authorization Grant (RFC 8628) verification pages.
// `terminal-device-client` (device_code grant) lives on the uitsmijter-tenant,
// whose provider accepts any credentials — see Deployment/e2e/uitsmijter-client.yaml
// and Deployment/e2e/uitsmijter-tenant.yaml.
const BASE = 'https://uitsmijter.localhost';
const DEVICE_CLIENT_ID = 'f8b3c2a1-0d1e-4f8b-9c2a-3d4e5f6a7b8c';

test.describe('Device Grant - activation page', () => {
    let app: Application;

    test.beforeEach(async ({page}) => {
        app = new Application(page);
        test.setTimeout(app.timeout);
    });

    // The verification page a user opens on their phone/laptop to enter the code.
    test('activation form should be present', async ({page}) => {
        await app.goto(`${BASE}/activate`);
        await app.waitForPage(page);

        await expect(page.locator('input#user_code')).toBeVisible();
        expect(await page.screenshot()).toMatchSnapshot();
    });

    // An unknown user_code must render the shake/error state.
    test('invalid code should show an error', async ({page}) => {
        await app.goto(`${BASE}/activate`);
        await page.fill('input#user_code', 'AAAA-AAAA');
        await page.fill('input#username', 'test');
        await page.fill('input#password', 'testing');
        await page.click('button#activateButton');
        await app.waitForPage(page);

        await expect(page.locator('.login-box.error')).toBeVisible();
        expect(await page.screenshot()).toMatchSnapshot();
    });

    // Full happy path: request a device code, then authorize it via the form.
    test('success page after authorizing a real code', async ({page}) => {
        const resp = await page.request.post(`${BASE}/oauth/device_authorization`, {
            form: {client_id: DEVICE_CLIENT_ID, scope: 'access'},
        });
        expect(resp.ok()).toBeTruthy();
        const userCode = (await resp.json()).user_code as string;

        await app.goto(`${BASE}/activate`);
        await page.fill('input#user_code', userCode);
        await page.fill('input#username', 'test');
        await page.fill('input#password', 'testing');
        await page.click('button#activateButton');
        await app.waitForPage(page);

        await expect(page.locator('.message[data-result="success"]')).toBeVisible();
        expect(await page.screenshot()).toMatchSnapshot();
    });
});
