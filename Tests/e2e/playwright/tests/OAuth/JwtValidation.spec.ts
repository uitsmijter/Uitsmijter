import {test, expect} from '@playwright/test';
import {Application} from "../Fixtures/app";
import {
    decodeJwt,
    getTokenForAuthorisationCode,
    loginAuthorizeFormRequest
} from "./AuthorizeRequests";
import {request} from "@playwright/test";
import jwt from 'jsonwebtoken';

test.describe('JWT Token Validation with JWKS', () => {

    test.beforeEach(async ({page}) => {
        const app = new Application(page)
        test.setTimeout(app.timeout)
    });

    test.describe('HS256 Tenant - Symmetric Signing', () => {
        test.describe.configure({mode: 'serial'});

        const myState = Math.floor(Math.random() * 999999999);
        let code: string = null;
        let accessToken: string = null;

        test('should complete OAuth flow and get HS256 token', async ({page}) => {
            const response = await loginAuthorizeFormRequest(
                page,
                'https://id.example.com',
                {
                    client_id: "143A3135-5DE2-46D4-828F-DDCF20C72060",
                    redirect_uri: "https://api.example.com/",
                    response_type: "code",
                    scope: "access",
                    state: "" + myState,
                    username: "cee8Esh5@example.com"
                }
            );

            expect(response.url()).toContain("state=" + myState);
            expect(response.url()).toContain("code=");
            code = response.url().match(/code=(.+)&/)[1];

            const tokenResponse = await getTokenForAuthorisationCode(
                'https://id.example.com',
                {
                    "grant_type": "authorization_code",
                    "client_id": "143A3135-5DE2-46D4-828F-DDCF20C72060",
                    "scope": "access",
                    "code": "" + code
                }
            );

            const jsonResponse = await tokenResponse.json();
            accessToken = jsonResponse.access_token;
        });

        test('should verify HS256 token uses symmetric algorithm', async () => {
            const decodedToken = decodeJwt(accessToken);

            // Verify header indicates HS256
            expect(decodedToken.header).toHaveProperty('alg');
            expect(decodedToken.header.alg).toBe('HS256');
            expect(decodedToken.header).toHaveProperty('typ');
            expect(decodedToken.header.typ).toBe('JWT');

            // HS256 tokens should NOT have kid (Key ID)
            expect(decodedToken.header).not.toHaveProperty('kid');
        });

        test('should confirm JWKS endpoint exists but may not contain HS256 keys', async () => {
            const context = await request.newContext();

            // Fetch OpenID configuration
            const configResponse = await context.get('https://id.example.com/.well-known/openid-configuration');
            expect(configResponse.ok()).toBe(true);

            const config = await configResponse.json();
            expect(config).toHaveProperty('jwks_uri');

            // Fetch JWKS
            const jwksResponse = await context.get(config.jwks_uri);
            expect(jwksResponse.ok()).toBe(true);

            const jwks = await jwksResponse.json();
            expect(jwks).toHaveProperty('keys');

            // JWKS should be an array (may be empty for HS256-only tenant)
            expect(Array.isArray(jwks.keys)).toBe(true);

            console.log(`HS256 tenant JWKS contains ${jwks.keys.length} keys (expected 0 for HS256-only)`);
        });

        test('should have valid token payload structure', async () => {
            const decodedToken = decodeJwt(accessToken);

            // Verify standard JWT claims
            expect(decodedToken.payload).toHaveProperty('iss'); // Issuer
            expect(decodedToken.payload).toHaveProperty('sub'); // Subject
            expect(decodedToken.payload).toHaveProperty('aud'); // Audience
            expect(decodedToken.payload).toHaveProperty('exp'); // Expiration
            expect(decodedToken.payload).toHaveProperty('iat'); // Issued At

            // Verify Uitsmijter-specific claims
            expect(decodedToken.payload).toHaveProperty('tenant');
            expect(decodedToken.payload.tenant).toBe('cheese/cheese');
        });
    });

    test.describe('RS256 Tenant - Asymmetric Signing with JWKS', () => {
        test.describe.configure({mode: 'serial'});

        const myState = Math.floor(Math.random() * 999999999);
        let code: string = null;
        let accessToken: string = null;

        test('should complete OAuth flow and get RS256 token', async ({page}) => {
            const response = await loginAuthorizeFormRequest(
                page,
                'https://id-rs256.example.com',
                {
                    client_id: "9F8E7D6C-5B4A-3210-FEDC-BA9876543210",
                    redirect_uri: "https://api-rs256.example.com/",
                    response_type: "code",
                    scope: "access",
                    state: "" + myState,
                    username: "cee8Esh5@example.com"
                }
            );

            expect(response.url()).toContain("state=" + myState);
            expect(response.url()).toContain("code=");
            code = response.url().match(/code=(.+)&/)[1];

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
        });

        test('should verify RS256 token uses asymmetric algorithm', async () => {
            const decodedToken = decodeJwt(accessToken);

            // Verify header indicates RS256
            expect(decodedToken.header).toHaveProperty('alg');
            expect(decodedToken.header.alg).toBe('RS256');
            expect(decodedToken.header).toHaveProperty('typ');
            expect(decodedToken.header.typ).toBe('JWT');

            // RS256 tokens MUST have kid (Key ID)
            expect(decodedToken.header).toHaveProperty('kid');
            expect(decodedToken.header.kid).toBeTruthy();

            console.log(`RS256 token kid: ${decodedToken.header.kid}`);
        });

        test('should fetch JWKS from OpenID configuration', async () => {
            const context = await request.newContext();

            // Fetch OpenID configuration
            const configResponse = await context.get('https://id-rs256.example.com/.well-known/openid-configuration');
            expect(configResponse.ok()).toBe(true);

            const config = await configResponse.json();

            // Verify required OpenID configuration fields
            expect(config).toHaveProperty('issuer');
            expect(config).toHaveProperty('jwks_uri');
            expect(config).toHaveProperty('id_token_signing_alg_values_supported');

            // Verify RS256 is listed as supported algorithm
            expect(config.id_token_signing_alg_values_supported).toContain('RS256');

            console.log(`JWKS URI: ${config.jwks_uri}`);
            expect(config.jwks_uri).toBe('https://id-rs256.example.com/.well-known/jwks.json');
        });

        test('should fetch and validate JWKS structure', async () => {
            const context = await request.newContext();

            // Fetch JWKS directly
            const jwksResponse = await context.get('https://id-rs256.example.com/.well-known/jwks.json');
            expect(jwksResponse.ok()).toBe(true);

            const jwks = await jwksResponse.json();

            // Verify JWKS structure (RFC 7517)
            expect(jwks).toHaveProperty('keys');
            expect(Array.isArray(jwks.keys)).toBe(true);
            expect(jwks.keys.length).toBeGreaterThan(0);

            // Verify first key structure
            const key = jwks.keys[0];
            expect(key).toHaveProperty('kty'); // Key Type (should be "RSA")
            expect(key.kty).toBe('RSA');
            expect(key).toHaveProperty('use'); // Public Key Use (should be "sig")
            expect(key.use).toBe('sig');
            expect(key).toHaveProperty('kid'); // Key ID
            expect(key).toHaveProperty('n'); // RSA modulus
            expect(key).toHaveProperty('e'); // RSA exponent

            // Verify key parameters are base64url encoded strings
            expect(typeof key.n).toBe('string');
            expect(typeof key.e).toBe('string');
            expect(key.e).toBe('AQAB'); // Common RSA exponent (65537)

            console.log(`JWKS contains ${jwks.keys.length} key(s)`);
            console.log(`First key ID: ${key.kid}`);
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

            console.log(`Found matching key for kid: ${kid}`);

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

            console.log('✓ Token signature verified successfully using JWKS public key');
        });

        test('should verify token is not expired', async () => {
            const decodedToken = decodeJwt(accessToken);
            const now = Math.floor(Date.now() / 1000);

            // Token should not be expired (exp > now)
            expect(decodedToken.payload.exp).toBeGreaterThan(now);

            // Token's iat should be reasonable (allowing 5 seconds clock skew for test timing variations)
            // The token was issued in a previous test, so iat could be slightly before or after 'now'
            expect(decodedToken.payload.iat).toBeLessThanOrEqual(now + 5);
            expect(decodedToken.payload.iat).toBeGreaterThan(now - 300); // Not older than 5 minutes

            const timeUntilExpiry = decodedToken.payload.exp - now;
            console.log(`Token expires in ${timeUntilExpiry} seconds`);
        });

        test('should verify multiple keys can coexist in JWKS', async () => {
            const context = await request.newContext();
            const jwksResponse = await context.get('https://id-rs256.example.com/.well-known/jwks.json');
            const jwks = await jwksResponse.json();

            // JWKS may contain multiple keys for rotation support
            // All keys should have unique kid values
            const kids = jwks.keys.map((key: any) => key.kid);
            const uniqueKids = new Set(kids);

            expect(kids.length).toBe(uniqueKids.size);
            console.log(`JWKS contains ${kids.length} unique key(s): ${kids.join(', ')}`);
        });
    });
});

/**
 * Convert JWK (JSON Web Key) to PEM format for use with jsonwebtoken library
 * This is a simplified implementation for RSA public keys
 */
function jwkToPem(jwk: any): string {
    // For a production implementation, use a library like 'jwk-to-pem'
    // This is a basic implementation for testing purposes

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
 * This follows the PKCS#1 / RFC 8017 format
 */
function buildRsaPublicKeyDer(modulus: Buffer, exponent: Buffer): Buffer {
    // ASN.1 INTEGER encoding
    const encodeInteger = (buffer: Buffer): Buffer => {
        // Add leading 0x00 if high bit is set (to indicate positive number)
        const needsPadding = buffer[0] >= 0x80;
        const paddedBuffer = needsPadding
            ? Buffer.concat([Buffer.from([0x00]), buffer])
            : buffer;

        // Tag: 0x02 (INTEGER), Length, Value
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

    // Tag: 0x30 (SEQUENCE), Length, Value
    const sequenceLength = encodeLength(sequenceContent.length);
    const rsaPublicKey = Buffer.concat([
        Buffer.from([0x30]),
        sequenceLength,
        sequenceContent
    ]);

    // Wrap in SPKI (Subject Public Key Info) structure
    // Algorithm Identifier for RSA encryption
    const algorithmIdentifier = Buffer.from([
        0x30, 0x0d, // SEQUENCE of length 13
        0x06, 0x09, // OID of length 9
        0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, // rsaEncryption OID
        0x05, 0x00  // NULL
    ]);

    // BIT STRING containing the RSA public key
    const bitStringLength = encodeLength(rsaPublicKey.length + 1);
    const bitString = Buffer.concat([
        Buffer.from([0x03]), // BIT STRING tag
        bitStringLength,
        Buffer.from([0x00]), // No unused bits
        rsaPublicKey
    ]);

    // Final SEQUENCE (SPKI)
    const spkiContent = Buffer.concat([algorithmIdentifier, bitString]);
    const spkiLength = encodeLength(spkiContent.length);

    return Buffer.concat([
        Buffer.from([0x30]), // SEQUENCE tag
        spkiLength,
        spkiContent
    ]);
}
