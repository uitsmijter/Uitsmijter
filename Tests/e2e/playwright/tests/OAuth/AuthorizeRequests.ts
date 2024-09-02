import {
  AuthorizeApiRequestData,
  AuthorizeFormRequestData,
} from "../types/AuthorizeRequestData";
import { Page, request } from "@playwright/test";
import {
  TokenRequestData,
  TokenRequestDataPassword,
  TokenRequestDataVerified,
} from "../types/TokenRequestData";
import { JwtToken } from "../types/JwtToken";
import jwt from "jsonwebtoken";
import { CodeRequestData } from "../types/CodeRequestData";

export async function authorizeFormRequest(
  url: string,
  data: AuthorizeFormRequestData,
) {
  const context = await request.newContext({
    baseURL: url,
    extraHTTPHeaders: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
  });

  return await context.post("/login", {
    form: {
      location:
        url +
        `/authorize?client_id=${data.client_id}&redirect_uri=${data.redirect_uri}&response_type=${data.response_type}&scope=${data.scope}&state=${data.state}` +
        `&code_challenge=${data.code_challenge}&code_challenge_method=${data.code_challenge_method}&response_mode=${data.response_mode}`,
      mode: "",
      username: data.username,
      password: "secretPassword",
    },
  });
}

export async function authorizeApiRequest(
  url: string,
  data: AuthorizeApiRequestData | CodeRequestData,
) {
  const context = await request.newContext({
    baseURL: url,
    extraHTTPHeaders: {
      "Content-Type": "application/json",
    },
  });

  return await context.get("/authorize", {
    params: { ...data },
  });
}

export async function authorizeApiRequestOnPage(
  page: Page,
  url: string,
  data: AuthorizeApiRequestData,
) {
  return await page.request.get(url + "/authorize", {
    headers: {
      "Content-Type": "application/json",
    },
    params: { ...data },
  });
}

export async function deviceApiRequest(
  url: string,
  data: AuthorizeApiRequestData | CodeRequestData,
) {
  const context = await request.newContext({
    baseURL: url,
    extraHTTPHeaders: {
      "Content-Type": "application/json",
    },
  });

  return await context.get("/device", {
    params: { ...data },
  });
}

export async function loginAuthorizeFormRequest(
  page: Page,
  url: string,
  data: AuthorizeFormRequestData,
) {
  const queryParams = {
    response_type: data.response_type,
    client_id: data.client_id,
    client_secret: data.client_secret || "null",
    redirect_uri: data.redirect_uri,
    scope: data.scope,
    state: data.state,
  };
  const queryString = new URLSearchParams(queryParams).toString();

  return await page.request.post(url + "/login", {
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    form: {
      location: "/authorize" + `?${queryString}`,
      mode: "",
      username: data.username,
      password: "secretPassword",
    },
  });
}

export async function getTokenForAuthorisationCode(
  url: string,
  data: TokenRequestData | TokenRequestDataPassword | TokenRequestDataVerified,
  token?: string,
) {
  let header = {
    "Content-Type": "application/json",
    Accept: "application/json",
  };
  if (token) {
    header["Authorization"] = "Bearer " + token;
  }
  const context = await request.newContext({
    baseURL: url,
    extraHTTPHeaders: header,
  });

  return await context.post("/token", {
    data: { ...data },
  });
}

export async function getTokenInfo(url: string, token: string) {
  const context = await request.newContext({
    baseURL: url,
    extraHTTPHeaders: {
      "Content-Type": "application/json",
      Authorization: "Bearer " + token,
      Accept: "application/json",
    },
  });
  return await context.get("/token/info", {});
}

export function decodeJwt(access_token: string): JwtToken {
  const b64d = (data: string): string =>
    Buffer.from(data, "base64").toString("binary");
  const token = access_token.split(".");
  const header = b64d(token[0]);
  const payload = b64d(token[1]);
  const signature = token[1];

  return {
    header: JSON.parse(header),
    payload: JSON.parse(payload),
    signature: signature,
  };
}

export function encodeJwt(
  payload: object,
  secret: string,
  options?: jwt.SignOptions,
): string {
  const token = jwt.sign(payload, secret, options);
  return token;
}
