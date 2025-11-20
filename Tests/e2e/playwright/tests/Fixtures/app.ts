import type {Page} from '@playwright/test';
import {Authentication} from "./authentication";

export class Application {
    auth: Authentication

    constructor(public readonly page: Page, timeout?: number) {
        this.timeout = typeof timeout !== "undefined" ? timeout : 60 / 2 * 1000
        this.auth = new Authentication(this)
    }

    async goto(url: string) {
        let response = await this.page.goto(url);
        await this.waitForPage()

        return response
    }

    async waitForPage(page?: Page, timeout?: number) {
        page = typeof page !== "undefined" ? page : this.page
        timeout = typeof timeout !== "undefined" ? timeout : this.timeout

        await page.waitForSelector('body', {state: 'attached', timeout: timeout});
        await page.waitForLoadState("domcontentloaded");
        await page.waitForLoadState("networkidle");

        if (page.context().browser()?.browserType().name() == "webkit") {
            // Webkit has problems with rendering the background image on time
            await page.waitForTimeout(250)
        }
    }
}
