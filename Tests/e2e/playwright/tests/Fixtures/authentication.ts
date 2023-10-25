import type {Page} from '@playwright/test';
import {Application} from './app';

export class Authentication {
    public readonly page: Page

    constructor(public readonly app: Application) {
        this.page = app.page
    }

    async login(username: string, password: string, page?: Page) {
        page = page || this.page

        await page.fill("input#username", username)
        await page.fill("input#password", password)
        await page.click("button#loginButton")

        await this.app.waitForPage(page)
    }
}
