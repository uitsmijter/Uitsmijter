import { test, expect } from "@playwright/test";
import { Application } from "../Fixtures/app";
import {
  authorizeApiRequest,
  decodeJwt,
  getTokenForAuthorisationCode,
  getTokenInfo,
  loginAuthorizeFormRequest,
  deviceApiRequest,
} from "./AuthorizeRequests";

test.describe("Device code OAuth flow", () => {
  test.beforeEach(async ({ page }) => {
    const app = new Application(page);
    test.setTimeout(app.timeout);
  });

  // https://docs.uitsmijter.io/oauth/flow/
  // ------------------------------------------------------
  // "forTestingPurposesOnly"
  // E819EDF6-2942-473E-B540-970A758E42A1 = cheese-api-device

  test.describe("complete lifecycle", () => {
    test.describe("happy path", async () => {
      // All tests in this describe must be executed in series
      test.describe.configure({ mode: "serial" });

      // Flow context
      const myState = Math.floor(Math.random() * 999999999);
      let code: string = null;
      let accessToken: string = null;
      let refreshToken: string = null;

      // Code Flow - Step 1
      // When the user wants to log in, the device starts out by making a POST request to
      // begin the process. The POST request contains only one piece of information, its client_id.
      // (Devices like these are considered “public clients”, so no client_secret is used in them, similar
      // to mobile apps. This request is made to a new endpoint that is unique to the Device Flow.
      test("should respond with a device code", async () => {
        const response = await deviceApiRequest(
          "https://id.example.com/device",
          {
            client_id: "E819EDF6-2942-473E-B540-970A758E42A1",
          },
        );

        await expect(response.headers()["server"]).toContain("Uitsmijter");
        await expect(response.status()).toBe(200);

        const content = await response.json();
        await expect(content).toHaveProperty("device_code");
        await expect(content).toHaveProperty("verification_uri");
        await expect(content).toHaveProperty("user_code");
        await expect(content).toHaveProperty("expires_in");
        await expect(content).toHaveProperty("interval");

        await expect(content.device_code).toBeDefined();
      });
    });
  });
});
