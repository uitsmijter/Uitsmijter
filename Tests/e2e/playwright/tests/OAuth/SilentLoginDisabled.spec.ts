import {test, expect, Cookie} from '@playwright/test'
import {Application} from "../Fixtures/app"
import {
    authorizeApiRequest, authorizeApiRequestOnPage,
    loginAuthorizeFormRequest
} from "./AuthorizeRequests"

test.describe('OAuth flow - Silent login disabled', () => {
    let app: Application

    test.beforeEach(async ({page}) => {
        app = new Application(page)
        test.setTimeout(app.timeout)
    })

    // https://docs.uitsmijter.io/oauth/flow/
    // ------------------------------------------------------
    // cd7a444a-7aa9-4f27-9305-9e2a9c4d47ee = ham/ham

    test.describe('complete lifecycle', () => {

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

        // Flow context
        const myState = Math.floor(Math.random() * 999999999)
        let code: string = null

        // General Auth 2 Flow - Step 1 - 2
        test('should respond with a login page to the request for an authorization code', async ({page}) => {
            const response = await authorizeApiRequestOnPage(
                page,
                'https://id.example.com',
                {
                    response_type: 'code',
                    client_id: 'cd7a444a-7aa9-4f27-9305-9e2a9c4d47ee',
                    client_secret: null,
                    redirect_uri: 'https://api1.ham.test/',
                    scope: '',
                    state: '' + myState
                }
            )

            await expect(response.headers()['server']).toContain('Uitsmijter')
            await expect(response.status()).toBe(401)

            const content = await response.text()
            await expect(content).toContain('form action="/login"')
        })

        // General Auth 2 Flow - Step 3 - 5
        test('should respond after login with a code for authorization', async ({page}) => {
            const response = await loginAuthorizeFormRequest(
                page,
                'https://id.example.com',
                {
                    client_id: "cd7a444a-7aa9-4f27-9305-9e2a9c4d47ee",
                    redirect_uri: "https://api1.ham.test/",
                    client_secret: null,
                    response_type: "code",
                    scope: "access",
                    state: "" + myState,
                    username: "cee8Esh5@example.com"
                }
            )

            expect(response.url()).toMatch(/^https:\/\/api1\.ham\.test/)
            expect(response.url()).toContain("state=" + myState)
            expect(response.url()).toContain("code=")
            code = response.url().match(/code=(.+)&/)[1]
            expect(code.length).toBeGreaterThan(0)
        })

        // General Auth 2 Flow - Step 1 - 2 - no silent redirect
        test('should respond without a redirect back to the login page', async ({page}) => {
            const response = await authorizeApiRequestOnPage(
                page,
                'https://id.example.com',
                {
                    response_type: 'code',
                    client_id: 'cd7a444a-7aa9-4f27-9305-9e2a9c4d47ee',
                    client_secret: null,
                    redirect_uri: 'https://api2.ham.test/',
                    scope: '',
                    state: '' + myState
                }
            )

            // Show login page as no auto login should happen
            await expect(response.headers()['server']).toContain('Uitsmijter')
            await expect(response.status()).toBe(401)

            const content = await response.text()
            await expect(content).toContain('form action="/login"')
        })

    })

})
