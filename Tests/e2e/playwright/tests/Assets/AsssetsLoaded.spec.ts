import {test, expect, Page} from '@playwright/test'
import {Application} from '../Fixtures/app';

test.describe('Assets loading for', () => {
    let responses = []
    let app: Application

    test.beforeEach(async ({page}) => {
        // Reset state
        responses = []
        // Subscribe to 'response' network events.
        page.on('response', response => responses.push([response.url(), response.status()]))
        page.on('requestfailed', request => responses.push([request.url(), request.failure().errorText]))

        app = new Application(page)
        test.setTimeout(app.timeout!)
    })

    test('login page should be present', async ({page}) => {
        await app.goto('https://login.example.com/login?for=http://cookbooks.example.com')
        await app.waitForPage(page)
        await expectAssetsLoaded()
        
        expect(await page.screenshot()).toMatchSnapshot();
    })

    test('logout page should be present', async ({page}) => {
        await app.goto('https://login.example.com/login?for=http://cookbooks.example.com')
        await app.auth.login('test@example.com', 'test')
        await app.goto('https://login.example.com/logout?for=http://cookbooks.example.com')

        await expectAssetsLoaded()
        expect(await page.screenshot()).toMatchSnapshot();
    })

    test('error page should be present', async ({page}) => {
        await app.goto('https://login.example.com/error')

        await expectAssetsLoaded()
        expect(await page.screenshot()).toMatchSnapshot();
    })

    test('unknown tenant error page should be present', async ({page}, testInfo) => {
        await app.goto('https://missing-tenant.example.com')

        await expectAssetsLoaded()
        expect(await page.screenshot()).toMatchSnapshot();
    })

    async function expectAssetsLoaded() {
        for await (const response of responses) {
            const url: string = response[0]
            const status: number = response[1]

            // Ignore redirects and non-asset URLs
            if ((status >= 300 && status < 400) || !/.*\.(png|jpe?g|svg|css|js|ttf|ico|eto|woff2?)($|\?.*)/.test(url)) {
                continue
            }

            expect(status, "Unsuccessful response for " + url).toBe(200)
        }
    }
})
