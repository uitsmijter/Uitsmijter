import {test, expect} from '@playwright/test';
import {Application} from "../Fixtures/app";
import {
    decodeJwt,
    getTokenForAuthorisationCode,
    loginAuthorizeFormRequest
} from "./AuthorizeRequests";
import {request} from "@playwright/test";
import jwt from 'jsonwebtoken';

/**
 * E2E Test for RS256 Token Signing with Scope Enrichment
 *
 * This test verifies that:
 * 1. Client requests scope: "access"
 * 2. Provider pushes scope: "user:list"
 * 3. Final token contains both: "access user:list"
 * 4. Token is signed with RS256
 * 5. Token can be verified using the public key from .well-known/jwks.json
 */
test.describe('RS256 Scope Enrichment with JWKS Verification', () => {

    test.beforeEach(async ({page}) => {
        const app = new Application(page)
        test.setTimeout(app.timeout)
    });

    test.describe('Scope Enrichment Flow', () => {
        test.describe.configure({mode: 'serial'});

        const myState = Math.floor(Math.random() * 999999999);
        let code: string = null;
        let accessToken: string = null;

        test('should complete OAuth flow with scope enrichment', async ({page}) => {
            // 1. Login and get authorization code with "access" scope
            const response = await loginAuthorizeFormRequest(
                page,
                'https://id-rs256.example.com',
                {
                    client_id: "9F8E7D6C-5B4A-3210-FEDC-BA9876543210",
                    redirect_uri: "https://api-rs256.example.com/",
                    response_type: "code",
                    scope: "access",  // Client requests "access" scope
                    state: "" + myState,
                    username: "testuser@example.com"
                }
            );

            expect(response.url()).toContain("state=" + myState);
            expect(response.url()).toContain("code=");
            code = response.url().match(/code=(.+)&/)[1];

            // 2. Exchange authorization code for access token
            const tokenResponse = await getTokenForAuthorisationCode(
                'https://id-rs256.example.com',
                {
                    "grant_type": "authorization_code",
                    "client_id": "9F8E7D6C-5B4A-3210-FEDC-BA9876543210",
                    "scope": "access",
                    "code": "" + code
                }
            );

            const jsonResponse = await tokenResponse.json();
            accessToken = jsonResponse.access_token;

            // 3. Verify TokenResponse contains both scopes
            expect(jsonResponse).toHaveProperty('scope');
            expect(jsonResponse.scope).toContain('access');
            expect(jsonResponse.scope).toContain('user:list');

            console.log('✓ TokenResponse scope:', jsonResponse.scope);
        });

        test('should have RS256 algorithm in token header', async () => {
            const decodedToken = decodeJwt(accessToken);

            // Verify header indicates RS256
            expect(decodedToken.header).toHaveProperty('alg');
            expect(decodedToken.header.alg).toBe('RS256');
            expect(decodedToken.header).toHaveProperty('typ');
            expect(decodedToken.header.typ).toBe('JWT');

            // RS256 tokens MUST have kid (Key ID)
            expect(decodedToken.header).toHaveProperty('kid');
            expect(decodedToken.header.kid).toBeTruthy();

            console.log('✓ Token algorithm: RS256');
            console.log('✓ Token kid:', decodedToken.header.kid);
        });

        test('should verify token payload contains both scopes', async () => {
            const decodedToken = decodeJwt(accessToken);

            // Verify payload structure
            expect(decodedToken.payload).toHaveProperty('scope');
            expect(decodedToken.payload.scope).toBeTruthy();

            // Verify both scopes are present
            const scopes = decodedToken.payload.scope.split(' ');
            expect(scopes).toContain('access');
            expect(scopes).toContain('user:list');

            console.log('✓ Token payload scopes:', decodedToken.payload.scope);
        });

        test('should fetch JWKS and find matching key', async () => {
            const context = await request.newContext();
            const decodedToken = decodeJwt(accessToken);
            const kid = decodedToken.header.kid;

            // Fetch JWKS from .well-known/jwks.json
            const jwksResponse = await context.get('https://id-rs256.example.com/.well-known/jwks.json');
            expect(jwksResponse.ok()).toBe(true);

            const jwks = await jwksResponse.json();

            // Verify JWKS structure
            expect(jwks).toHaveProperty('keys');
            expect(Array.isArray(jwks.keys)).toBe(true);
            expect(jwks.keys.length).toBeGreaterThan(0);

            // Find the key matching the token's kid
            const signingKey = jwks.keys.find((key: any) => key.kid === kid);
            expect(signingKey).toBeDefined();

            // Verify key structure
            expect(signingKey.kty).toBe('RSA');
            expect(signingKey.use).toBe('sig');
            expect(signingKey.alg).toBe('RS256');
            expect(signingKey.n).toBeTruthy();
            expect(signingKey.e).toBe('AQAB');

            console.log('✓ Found matching JWKS key with kid:', kid);
            console.log('✓ Key type:', signingKey.kty);
            console.log('✓ Key algorithm:', signingKey.alg);
        });

        test('should verify RS256 token signature using JWKS public key', async () => {
            const context = await request.newContext();
            const decodedToken = decodeJwt(accessToken);
            const kid = decodedToken.header.kid;

            // Fetch JWKS
            const jwksResponse = await context.get('https://id-rs256.example.com/.well-known/jwks.json');
            const jwks = await jwksResponse.json();

            // Find the key matching the token's kid
            const signingKey = jwks.keys.find((key: any) => key.kid === kid);
            expect(signingKey).toBeDefined();

            console.log('✓ Found signing key for kid:', kid);

            // Convert JWK to PEM format for verification
            const publicKey = jwkToPem(signingKey);

            // Verify token signature using the public key
            let verified = false;
            let verifiedPayload: any = null;

            try {
                verifiedPayload = jwt.verify(accessToken, publicKey, {
                    algorithms: ['RS256'],
                    complete: false
                });
                verified = true;
            } catch (error) {
                console.error('Token verification failed:', error);
                verified = false;
            }

            expect(verified).toBe(true);
            expect(verifiedPayload).toBeTruthy();

            // Verify the payload matches what we decoded earlier
            expect(verifiedPayload.sub).toBe(decodedToken.payload.sub);
            expect(verifiedPayload.aud).toBe(decodedToken.payload.aud);
            expect(verifiedPayload.tenant).toBe('cheese/cheese-rs256');

            // CRITICAL: Verify both scopes are present in verified token
            expect(verifiedPayload.scope).toContain('access');
            expect(verifiedPayload.scope).toContain('user:list');

            console.log('✓ Token signature verified successfully using JWKS public key');
            console.log('✓ Verified token scopes:', verifiedPayload.scope);
        });

        test('should confirm scope enrichment: client request + provider push', async () => {
            const context = await request.newContext();
            const decodedToken = decodeJwt(accessToken);

            // Fetch JWKS and verify token
            const jwksResponse = await context.get('https://id-rs256.example.com/.well-known/jwks.json');
            const jwks = await jwksResponse.json();
            const signingKey = jwks.keys.find((key: any) => key.kid === decodedToken.header.kid);
            const publicKey = jwkToPem(signingKey);

            const verifiedPayload = jwt.verify(accessToken, publicKey, {
                algorithms: ['RS256'],
                complete: false
            }) as any;

            // Verify scope enrichment worked correctly:
            // - "access" comes from client request
            // - "user:list" comes from provider's scopes() getter
            const scopes = verifiedPayload.scope.split(' ').sort();
            expect(scopes).toEqual(['access', 'user:list']);

            // Verify no other scopes leaked through
            expect(scopes.length).toBe(2);

            console.log('✓ Scope enrichment verified:');
            console.log('  - Client requested: access');
            console.log('  - Provider pushed: user:list');
            console.log('  - Final token scopes:', scopes.join(', '));
        });
    });

    test.describe('Password Grant Flow with Scope Enrichment', () => {
        test.describe.configure({mode: 'serial'});

        let accessToken: string = null;

        test('should get token via password grant with scope enrichment', async () => {
            const context = await request.newContext();

            // Request token via password grant with "access" scope
            const tokenResponse = await context.post('https://id-rs256.example.com/token', {
                headers: {
                    'Content-Type': 'application/json',
                },
                data: {
                    grant_type: 'password',
                    client_id: '9F8E7D6C-5B4A-3210-FEDC-BA9876543210',
                    scope: 'access',  // Client requests "access" scope
                    username: 'testuser@example.com',
                    password: 'any_password'
                }
            });

            expect(tokenResponse.ok()).toBe(true);

            const tokenResponseBody = await tokenResponse.json();
            accessToken = tokenResponseBody.access_token;

            expect(accessToken).toBeTruthy();

            // Verify TokenResponse contains both scopes (client + provider)
            expect(tokenResponseBody).toHaveProperty('scope');
            expect(tokenResponseBody.scope).toContain('access');
            expect(tokenResponseBody.scope).toContain('user:list');

            console.log('✓ Password grant TokenResponse scope:', tokenResponseBody.scope);
        });

        test('should verify password grant token signature using JWKS public key', async () => {
            const context = await request.newContext();
            const decodedToken = decodeJwt(accessToken);
            const kid = decodedToken.header.kid;

            // Fetch JWKS
            const jwksResponse = await context.get('https://id-rs256.example.com/.well-known/jwks.json');
            const jwks = await jwksResponse.json();

            // Find the key matching the token's kid
            const signingKey = jwks.keys.find((key: any) => key.kid === kid);
            expect(signingKey).toBeDefined();

            console.log('✓ Found signing key for password grant token kid:', kid);

            // Convert JWK to PEM format for verification
            const publicKey = jwkToPem(signingKey);

            // Verify token signature using the public key
            let verified = false;
            let verifiedPayload: any = null;

            try {
                verifiedPayload = jwt.verify(accessToken, publicKey, {
                    algorithms: ['RS256'],
                    complete: false
                });
                verified = true;
            } catch (error) {
                console.error('Password grant token verification failed:', error);
                verified = false;
            }

            expect(verified).toBe(true);
            expect(verifiedPayload).toBeTruthy();

            // CRITICAL: Verify both scopes are present in verified token
            expect(verifiedPayload.scope).toContain('access');
            expect(verifiedPayload.scope).toContain('user:list');

            console.log('✓ Password grant token signature verified successfully using JWKS public key');
            console.log('✓ Verified password grant token scopes:', verifiedPayload.scope);
        });

        test('should confirm password grant scope enrichment matches authorization code flow', async () => {
            const context = await request.newContext();
            const decodedToken = decodeJwt(accessToken);

            // Fetch JWKS and verify token
            const jwksResponse = await context.get('https://id-rs256.example.com/.well-known/jwks.json');
            const jwks = await jwksResponse.json();
            const signingKey = jwks.keys.find((key: any) => key.kid === decodedToken.header.kid);
            const publicKey = jwkToPem(signingKey);

            const verifiedPayload = jwt.verify(accessToken, publicKey, {
                algorithms: ['RS256'],
                complete: false
            }) as any;

            // Verify scope enrichment worked correctly (same as authorization_code flow):
            // - "access" comes from client request
            // - "user:list" comes from provider's scopes() getter
            const scopes = verifiedPayload.scope.split(' ').sort();
            expect(scopes).toEqual(['access', 'user:list']);

            // Verify no other scopes leaked through
            expect(scopes.length).toBe(2);

            console.log('✓ Password grant scope enrichment verified:');
            console.log('  - Client requested: access');
            console.log('  - Provider pushed: user:list');
            console.log('  - Final token scopes:', scopes.join(', '));
            console.log('  - Matches authorization_code flow behavior ✓');
        });
    });
});

/**
 * Convert JWK (JSON Web Key) to PEM format for use with jsonwebtoken library
 */
function jwkToPem(jwk: any): string {
    // Decode base64url to buffer
    const n = base64UrlToBuffer(jwk.n);
    const e = base64UrlToBuffer(jwk.e);

    // Build ASN.1 structure for RSA public key
    const publicKeyDer = buildRsaPublicKeyDer(n, e);

    // Convert to PEM format
    const base64Der = publicKeyDer.toString('base64');
    const pem = [
        '-----BEGIN PUBLIC KEY-----',
        base64Der.match(/.{1,64}/g)!.join('\n'),
        '-----END PUBLIC KEY-----'
    ].join('\n');

    return pem;
}

/**
 * Decode base64url string to Buffer
 */
function base64UrlToBuffer(base64url: string): Buffer {
    // Convert base64url to base64
    let base64 = base64url.replace(/-/g, '+').replace(/_/g, '/');

    // Add padding if needed
    while (base64.length % 4) {
        base64 += '=';
    }

    return Buffer.from(base64, 'base64');
}

/**
 * Build ASN.1 DER structure for RSA public key
 */
function buildRsaPublicKeyDer(modulus: Buffer, exponent: Buffer): Buffer {
    // ASN.1 INTEGER encoding
    const encodeInteger = (buffer: Buffer): Buffer => {
        const needsPadding = buffer[0] >= 0x80;
        const paddedBuffer = needsPadding
            ? Buffer.concat([Buffer.from([0x00]), buffer])
            : buffer;

        const lengthBuffer = encodeLength(paddedBuffer.length);
        return Buffer.concat([Buffer.from([0x02]), lengthBuffer, paddedBuffer]);
    };

    // ASN.1 length encoding
    const encodeLength = (length: number): Buffer => {
        if (length < 128) {
            return Buffer.from([length]);
        }

        const lengthBytes: number[] = [];
        let temp = length;
        while (temp > 0) {
            lengthBytes.unshift(temp & 0xff);
            temp >>= 8;
        }

        return Buffer.concat([
            Buffer.from([0x80 | lengthBytes.length]),
            Buffer.from(lengthBytes)
        ]);
    };

    // Build SEQUENCE of (modulus, exponent)
    const modulusEncoded = encodeInteger(modulus);
    const exponentEncoded = encodeInteger(exponent);
    const sequenceContent = Buffer.concat([modulusEncoded, exponentEncoded]);

    const sequenceLength = encodeLength(sequenceContent.length);
    const rsaPublicKey = Buffer.concat([
        Buffer.from([0x30]),
        sequenceLength,
        sequenceContent
    ]);

    // Wrap in SPKI (Subject Public Key Info) structure
    const algorithmIdentifier = Buffer.from([
        0x30, 0x0d,
        0x06, 0x09,
        0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01,
        0x05, 0x00
    ]);

    const bitStringLength = encodeLength(rsaPublicKey.length + 1);
    const bitString = Buffer.concat([
        Buffer.from([0x03]),
        bitStringLength,
        Buffer.from([0x00]),
        rsaPublicKey
    ]);

    const spkiContent = Buffer.concat([algorithmIdentifier, bitString]);
    const spkiLength = encodeLength(spkiContent.length);

    return Buffer.concat([
        Buffer.from([0x30]),
        spkiLength,
        spkiContent
    ]);
}
