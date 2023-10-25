import {test, expect} from '@playwright/test';

const timeout = 60 / 2 * 1000;

test('has title', async ({page}) => {
    test.setTimeout(timeout);
    await page.goto('https://uitsmijter.localhost/login');

    // Expect a title "to contain" a substring.
    await expect(page).toHaveTitle(/Login/);
});

test('imprint link', async ({page}) => {
    test.setTimeout(timeout);
    await page.goto('https://uitsmijter.localhost/login');

    // Click the get started link.
    await page.getByRole('link', {name: 'Impressum'}).click();

    // Expects the URL to contain intro.
    await expect(page).toHaveURL(/.*imprint.*/);
});
