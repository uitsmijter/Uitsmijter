import {test, expect, Page, Cookie} from '@playwright/test';
import {Application} from "../Fixtures/app";
import {Authentication} from "../Fixtures/authentication";
import {decodeJwt, encodeJwt} from "../OAuth/AuthorizeRequests";


const timeout = 60 / 2 * 1000;
test.describe('Cheese Cookbooks Interceptor Invalid Refresh User', () => {
    test.describe.configure({mode: 'serial'});

    let app: Application = null;
    let cookies: Cookie[] = [];

    test.beforeEach(async ({page}) => {
        app = new Application(page, timeout);
        test.setTimeout(app.timeout);
    });

    async function fillLoginForm(page: Page) {
        const app = new Application(page, timeout);
        await app.auth.login("nosecondtime@example.com", "se*retpassw0rd");
    }

    test.describe('should be protected', () => {
        test('and not showing the Cookbook', async ({page}) => {
            await page.goto('https://cookbooks.example.com/');
            await app.waitForPage();

            // Expect a title form a login page, not from the secured webpage
            await expect(page).not.toHaveTitle(/Cookbooks/);
            await expect(page).toHaveTitle(/Login/);
        });
    });

    test.describe('should be accessible', () => {

        test('after enter correct credentials', async ({page}) => {
            await page.goto('https://cookbooks.example.com/');
            await app.waitForPage()

            await fillLoginForm(page)
            await expect(page).toHaveURL("https://cookbooks.example.com/")
            await expect(page).toHaveTitle(/Cookbooks/);

            const headline = await page.locator("h1").first();
            await expect(headline).toContainText("Ingredients for an Uitsmijter");

            cookies = await page.context().cookies();
        });

        test('and a cookie is present', async ({page}) => {
            expect(cookies.length).toBeGreaterThan(0);
            expect(cookies.map(cookie => {
                return cookie.name
            })).toContain("uitsmijter-sso");
            expect(cookies.map(cookie => {
                return cookie.domain
            })).toContain(".example.com");
        });

    });

    test.describe('should still be accessible', () => {
        test('without a refresh', async ({page}) => {
            await page.context().addCookies(cookies)
            await page.goto('https://cookbooks.example.com/');
            await expect(page).toHaveTitle(/Cookbooks/);

            const headline = await page.locator("h1").first();
            await expect(headline).toContainText("Ingredients for an Uitsmijter");
        });
    });

    test.describe('should redirect to login', () => {
        test('should manipulate the cookie', async () => {
            // Get the uitsmijter cookie
            let ssoCookie = cookies.filter((cookie) => {
                return cookie.name == "uitsmijter-sso"
            }).pop();
            await expect(ssoCookie).toBeTruthy();

            // Recalculate the date
            let nowDate = new Date();
            let futureDate = new Date((nowDate.getTime() / 1000 + 60) * 1000);
            await expect(futureDate.getTime()).toBeGreaterThan(nowDate.getTime())

            // set new date
            ssoCookie.expires = Math.round(futureDate.getTime() / 1000)
            const jwtPayload = decodeJwt(ssoCookie.value).payload
            jwtPayload.exp = ssoCookie.expires;

            // re-encode the payload
            let newPayload = encodeJwt(jwtPayload, "forTestingPurposesOnly");
            ssoCookie.value = newPayload

            // push the cookie back in
            cookies = cookies.map((cookie) => {
                if (cookie.name != ssoCookie.name) {
                    return cookie
                }
                return ssoCookie
            })
        });

        test('after refresh is triggered', async ({page}) => {
            await page.context().addCookies(cookies)
            await page.goto('https://cookbooks.example.com/');
            
            await expect(page).toHaveTitle(/Error | 403/);
            await expect(await page.content()).toContain("ERRORS.INVALIDATE")
        });
    });
});
