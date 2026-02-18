import {test, expect, Cookie} from '@playwright/test'
import {Application} from "../Fixtures/app"

test.describe('Egg wildcard logout', () => {
    let app: Application

    test.beforeEach(async ({page}) => {
        app = new Application(page)
        test.setTimeout(app.timeout)
    })

    test.describe('Logout clears cross-subdomain session', () => {

        // All tests in this describe must be executed in series
        test.describe.configure({mode: 'serial'})

        // Global cookie store
        let cookies: Array<Cookie> = []

        test.beforeEach(async ({page}) => {
            page.context().addCookies(cookies)
        })
        test.afterEach(async ({page}) => {
            cookies = await page.context().cookies()
        })

        test('Login on yolk subdomain', async ({page}) => {
            await app.goto('https://yolk.egg.example.com/')
            await expect(page).toHaveTitle(/Login/)

            await app.auth.login("test@example.com", "test", page)
            await expect(page).toHaveTitle(/Yolk/)
        })

        test('Glair subdomain is accessible via shared cookie', async ({page}) => {
            await app.goto('https://glair.egg.example.com/')
            await expect(page).toHaveTitle(/Glair/)
        })

        test('Cookie domain is .example.com', async ({page}) => {
            let cookie = cookies.find(o => o.name === 'uitsmijter-sso')
            await expect(cookie.domain).toBe('.example.com')
        })

        test('Logout via login.example.com', async ({page}) => {
            await app.goto('https://login.example.com/logout?post_logout_redirect_uri=//yolk.egg.example.com')
            await page.waitForURL(/.*\/login.*/, {timeout: 5 * 1000})
            await expect(page).toHaveTitle(/Login/)

            const currentCookies = await page.context().cookies()
            expect(currentCookies.map(cookie => cookie.name)).not.toContain("uitsmijter-sso")
        })

        test('Glair subdomain requires login again after logout', async ({page}) => {
            await app.goto('https://glair.egg.example.com/')
            await expect(page).toHaveTitle(/Login/)
        })

    })
})
