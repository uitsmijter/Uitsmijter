import { createHash } from "crypto"


export function generateCodeVerifier() {
    const charset = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    let codeVerifier = '';
    for (let i = 0; i < 43; i++) {
        codeVerifier += charset[Math.floor(Math.random() * charset.length)];
    }
    return codeVerifier;
}

export function createCodeChallenge(codeVerifier) {
    // Perform SHA-256 hash of codeVerifier
    const hash = createHash('sha256');
    hash.update(codeVerifier);
    const codeChallenge = hash.digest('base64');

    // Base64-url encode the code challenge
    return codeChallenge.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
