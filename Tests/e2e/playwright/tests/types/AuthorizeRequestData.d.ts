export interface AuthorizeFormRequestData {
    response_type: "code" | "refresh"
    client_id: string
    client_secret?: string
    redirect_uri: string
    code_challenge?: string
    code_challenge_method?: "S256" | "PLAIN"
    response_mode?: "query"
    scope: string
    state: string
    username: string
}

export interface AuthorizeApiRequestData {
    response_type: "code" | "refresh"
    client_id: string
    client_secret?: string
    redirect_uri: string
    scope: string
    state: string
}
