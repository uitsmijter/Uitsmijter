import {test, expect, Cookie} from '@playwright/test'
import {Application} from "../Fixtures/app"

test.describe('Egg wildcard', () => {
    let app: Application

    test.beforeEach(async ({page}) => {
        app = new Application(page)
        test.setTimeout(app.timeout)
    })

    test.describe('Login to Yolk, goto Glair', () => {

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
            await app.goto('https://yolk.egg.example.com/')
            await expect(page).toHaveTitle(/Login/)
        })

        test('Redirect to yolk page after login', async ({page}) => {
            await app.goto('https://yolk.egg.example.com/')
            await expect(page).toHaveTitle(/Login/)

            await app.auth.login("test@example.com", "test", page)
            await expect(page).toHaveTitle(/Yolk/)
            
        })

        test('Glair page should also be accessible because of host wildcard', async ({page}) => {
            await app.goto('https://glair.egg.example.com/')
            await expect(page).toHaveTitle(/Glair/)
        })
        
        test('look inside cookies that they match the domain', async ({page}) => {
            let cookie = cookies.find(o => o.name === 'uitsmijter-sso')
            await expect(cookie.domain).toBe('.example.com')
        })

    })
})
