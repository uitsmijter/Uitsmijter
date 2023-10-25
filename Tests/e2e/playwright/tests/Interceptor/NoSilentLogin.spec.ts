import {test, expect, Cookie} from '@playwright/test'
import {Application} from "../Fixtures/app"

test.describe('No Silent login to ham', () => {
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
            await app.goto('https://page.ham.test/')
            await expect(page).toHaveTitle(/Login/)
        })

        test('Redirect to Ham page after login', async ({page}) => {
            await app.goto('https://page.ham.test/')
            await expect(page).toHaveTitle(/Login/)

            await app.auth.login("test@example.com", "test", page)
            await expect(page).toHaveTitle("A hilarious ham named Hank")
        })

        test('Visit Shop show new login page', async ({page}) => {
            await app.goto('https://shop.ham.test/')
            await expect(page).toHaveTitle(/Login/)
        })

    })
})
