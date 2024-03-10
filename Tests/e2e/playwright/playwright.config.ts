import {defineConfig, devices} from '@playwright/test';

/**
 * Read environment variables from file.
 * https://github.com/motdotla/dotenv
 */
// require('dotenv').config();

let defaultViewportDesktop = {width: 1920, height: 1080}

let projectsExtras = [];
// Extras when not in a GitHub-Workflow
if( ! process.env.GITHUB_ACTION ){
    projectsExtras = [{
             name: 'firefox',
             use: {
                 ...devices['Desktop Firefox'],
                 viewport: defaultViewportDesktop
             },
    }]
}

/**
 * See https://playwright.dev/docs/test-configuration.
 */
export default defineConfig({
    testDir: './tests',
    /* Run tests in files in parallel */
    fullyParallel: true,
    /* Fail the build on CI if you accidentally left test.only in the source code. */
    forbidOnly: !!process.env.CI,
    /* Retry on CI only */
    retries: process.env.CI ? 2 : 0,
    /* Opt out of parallel tests on CI. */
    workers: process.env.CI ? 1 : 4,
    /* Reporter to use. See https://playwright.dev/docs/test-reporters */
    reporter: 'line',
    /* Shared settings for all the projects below. See https://playwright.dev/docs/api/class-testoptions. */
    use: {
        /* Base URL to use in actions like `await page.goto('/')`. */
        // baseURL: 'http://127.0.0.1:3000',

        /* Collect trace when retrying the failed test. See https://playwright.dev/docs/trace-viewer */
        trace: 'on-first-retry',

        /* traefik's self-sign certificate is not valid, so wie ignore all https errors */
        ignoreHTTPSErrors: true
    },
    expect: {
        toMatchSnapshot: {
            // An acceptable ratio of pixels that are different to the total amount of pixels, between 0 and 1.
            maxDiffPixelRatio: 0.05,
        }
    },
    /* Configure projects for major browsers */
    projects: [
        ...projectsExtras,
        // Desktop
        {
            name: 'chromium',
            use: {
                ...devices['Desktop Chrome'],
                viewport: defaultViewportDesktop
            },
        },
        {
            name: 'webkit',
            use: {
                ...devices['Desktop Safari'],
                viewport: defaultViewportDesktop
            },
        },
        // Mobile:
        {
            name: 'mobile-pixel',
            use: {
                ...devices['Pixel 4a (5G)']
            },
        },
        {
            name: 'mobile-safari',
            use: {
                ...devices['iPhone 12']
            },
        },
    ],

    /* Run your local dev server before starting the tests */
    // webServer: {
    //   command: 'npm run start',
    //   url: 'http://127.0.0.1:3000',
    //   reuseExistingServer: !process.env.CI,
    // },
});
