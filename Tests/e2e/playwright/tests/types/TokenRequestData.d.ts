export interface TokenRequestData {
    grant_type: "authorization_code" | "refresh_token" | "password"
    client_id: string
    scope?: string,
    code?: string,
    refresh_token?: string
}

export interface TokenRequestDataPassword extends TokenRequestData {
    grant_type: "password",
    client_secret?: string,
    username: string,
    password: string,
}

export interface TokenRequestDataVerified extends TokenRequestData {
    grant_type: "authorization_code",
    client_secret?: string,
    code_verifier: string,
    code?: string,
}
