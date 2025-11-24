import {test} from '@playwright/test';

test.describe('Cheese Cookbooks Interceptor Delayed Login', () => {
    test.setTimeout(10000); // 5s delay in test, set timeout to 2x

    test.skip('should show the login spinner', async ({page}) => {
        await page.goto('https://cookbooks.example.com/');
        await page.fill("input#username", "delayed-login@example.com")
        await page.fill("input#password", "se*retpassw0rd")
        await page.click("button#loginButton", {noWaitAfter: true})
        await page.pause()
    });

});
