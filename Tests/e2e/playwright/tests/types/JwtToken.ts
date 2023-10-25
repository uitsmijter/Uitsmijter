export interface JwtToken {
    header: JwtHeader,
    payload: JwtData,
    signature: string,
}

export interface JwtHeader {
    typ: 'JWT',
    alg: string,
}

export interface JwtData {
    sub?: string,
    exp?: number,

    profile?: object,
    role?: string,
    tenant?: string
    user?: string
}
