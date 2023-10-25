import {test, expect, Cookie} from '@playwright/test'
import {Application} from "../Fixtures/app"

test.describe('Silent login', () => {
    let app: Application

    test.beforeEach(async ({page}) => {
        app = new Application(page)
        test.setTimeout(app.timeout)
    })

    test.describe('complete lifecycle on same domain', () => {

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

        test('Show login page on first visit', async ({page}) => {
            await app.goto('https://cookbooks.example.com/')
            await expect(page).toHaveTitle(/Login/)
        })

        test('Redirect to Cookbook after login', async ({page}) => {
            await app.goto('https://login.example.com/login?for=https://cookbooks.example.com/&mode=interceptor')
            await app.auth.login("test@example.com", "test")
            await expect(page).toHaveTitle(/Cookbook/)
        })

        test('Visit Toast without new login', async ({page}) => {
            await app.goto('https://toast.example.com/')
            await expect(page).toHaveTitle(/Toast/)
        })

        test('Automatically from login page to target page', async ({page}) => {
            test.fail() // Currently not working because silent login is set to nil instead of default true on k8s -> UIT-316

            await app.goto('https://login.example.com/login?for=https://cookbooks.example.com/&mode=interceptor')
            await expect(page).toHaveTitle(/Cookbook/)
        })

        test('visit SPA page and log in', async ({page}) => {
            // Currently not working because silent login is set to nil instead of default true on k8s -> UIT-316
            test.fail()

            await app.goto('https://spa.example.net')

            const loginButton = page.locator('#login');
            await expect(loginButton).toBeVisible()

            await page.click('#login')
            await app.waitForPage()

            // Should automatically add a ?code (user is still logged in) and redirect to the spa page
            await expect(page).toHaveTitle(/SPA/)

            const tokenInfo = page.locator('#tokenInfo');
            await expect(tokenInfo).toContainText("access_token")
        })

    })
})
