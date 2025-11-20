import {test, expect, Cookie} from '@playwright/test'
import {Application} from "../Fixtures/app"
import {
    authorizeApiRequest, authorizeApiRequestOnPage,
    loginAuthorizeFormRequest
} from "./AuthorizeRequests"
import { createCodeChallenge, generateCodeVerifier } from './Pkce'

test.describe('OAuth flow - Silent login enabled', () => {
    let app: Application

    test.beforeEach(async ({page}) => {
        app = new Application(page)
        test.setTimeout(app.timeout)
    })

    // https://docs.uitsmijter.io/oauth/flow/
    // ------------------------------------------------------
    // e942df47-4810-4a9a-8f25-47e8cf03325d = bnbc/bnbc
    // 4ad5d978-98b1-436b-8df6-316d700cf8f2 = bnbc/another-bnbc

    test.describe('complete lifecycle', () => {

        // All tests in this describe must be executed in series
        test.describe.configure({mode: 'serial'})

        // Global cookie store
        let cookies: Array<Cookie> = []

        test.beforeEach(async ({context}) => {
            context.addCookies(cookies)
        })
        test.afterEach(async ({context}) => {
            cookies = await context.cookies()
        })

        // Flow context
        const myState = Math.floor(Math.random() * 999999999)
        const codeVerifier = generateCodeVerifier()
        const codeChallenge = createCodeChallenge(codeVerifier)
        let code: string = null

        // General Auth 2 Flow - Step 1 - 2
        test('should respond with a login page to the request for an authorization code', async () => {
            const response = await authorizeApiRequest(
                'https://login.bnbc.example',
                {
                    response_type: 'code',
                    client_id: 'e942df47-4810-4a9a-8f25-47e8cf03325d',
                    client_secret: null,
                    redirect_uri: 'https://api1.bnbc.example/',
                    scope: '',
                    state: '' + myState,
                    code_challenge: codeChallenge,
                    code_challenge_method: 'S256'
                }
            )
            await expect(response.headers()['server']).toContain('Uitsmijter')
            await expect(response.status()).toBe(401)
            await expect(response.url()).toContain('/authorize')
            await expect(response.url()).toContain('response_type=code')
            
            const content = await response.text()
            await expect(content).toContain('form action="/login"')
        })

        // General Auth 2 Flow - Step 3 - 5
        test('should respond after login with a code for authorization', async ({page}) => {
            const response = await loginAuthorizeFormRequest(
                page,
                'https://login.bnbc.example',
                {
                    response_type: "code",
                    client_id: "e942df47-4810-4a9a-8f25-47e8cf03325d",
                    redirect_uri: "https://api1.bnbc.example/",
                    scope: "access",
                    state: "" + myState,
                    username: "cee8Esh5@example.com",
                    code_challenge: codeChallenge,
                    code_challenge_method: 'S256'
                }
            )

            expect(response.url()).toMatch(/^https:\/\/api1\.bnbc\.example/)
            expect(response.url()).toContain("state=" + myState)
            expect(response.url()).toContain("code=")
            code = response.url().match(/code=(.+)&/)[1]
            expect(code.length).toBeGreaterThan(0)
        })


        test('should have set auth cookies', async () => {
            expect(cookies.map(cookie => {
                return cookie.name
            })).toContain("uitsmijter-sso");
        })

        // General Auth 2 Flow - Step 1 - 2 - silent redirect
        test('should respond with a redirect back to the requesting page with an authorization code', async ({page}) => {
            const response = await authorizeApiRequestOnPage(
                page,
                'https://login.bnbc.example',
                {
                    response_type: 'code',
                    client_id: 'e942df47-4810-4a9a-8f25-47e8cf03325d',
                    client_secret: null,
                    redirect_uri: 'https://api2.bnbc.example/',
                    scope: '',
                    state: '' + myState,
                    code_challenge: codeChallenge,
                    code_challenge_method: 'S256'
                }
            )

            expect(response.url()).toMatch(/^https:\/\/api2\.bnbc\.example/)
            expect(response.url()).toContain("state=" + myState)
            expect(response.url()).toContain("code=")
            code = response.url().match(/code=(.+)&/)[1]
            expect(code.length).toBeGreaterThan(0)
        })

        // General Auth 2 Flow - Step 1 - 2 - silent redirect
        test('different client should respond with a redirect back to the requesting page with an authorization code', async ({page}) => {
            const response = await authorizeApiRequestOnPage(
                page,
                'https://login.bnbc.example',
                {
                    response_type: 'code',
                    client_id: '4ad5d978-98b1-436b-8df6-316d700cf8f2',
                    client_secret: null,
                    redirect_uri: 'https://api2.bnbc.example/',
                    scope: '',
                    state: '' + myState,
                    code_challenge: codeChallenge,
                    code_challenge_method: 'S256'
                }
            )

            expect(response.url()).toMatch(/^https:\/\/api2\.bnbc\.example/)
            expect(response.url()).toContain("state=" + myState)
            expect(response.url()).toContain("code=")
            code = response.url().match(/code=(.+)&/)[1]
            expect(code.length).toBeGreaterThan(0)
        })

    })

})
