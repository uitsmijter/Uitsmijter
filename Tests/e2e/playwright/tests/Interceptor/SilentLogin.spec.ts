import {test, expect, Cookie} from '@playwright/test'
import {Application} from "../Fixtures/app"

test.describe('Silent login to bnbc', () => {
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
            await app.goto('https://blog.bnbc.example/')
            await expect(page).toHaveTitle(/Login/)
        })

        test('Redirect to bnbc page after login', async ({page}) => {
            await app.goto('https://login.bnbc.example/login?for=https://blog.bnbc.example/&mode=interceptor')
            await app.auth.login("test@example.com", "test")
            await expect(page).toHaveTitle("Slice & Spread")
        })

        test('Visit Shop show page content after login auth redirects', async ({page}) => {
            await app.goto('https://shop.bnbc.example/')
            await expect(page).toHaveTitle(/The power of culinary creativity/)
        })

    })
})
