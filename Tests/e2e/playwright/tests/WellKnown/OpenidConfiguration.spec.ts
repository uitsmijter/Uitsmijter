import {test, expect} from '@playwright/test';
import {Application} from "../Fixtures/app";

/**
 * E2E Tests for OpenID Connect Discovery Endpoint
 *
 * These tests verify the `/.well-known/openid-configuration` endpoint
 * for OpenID Connect Discovery 1.0 compliance across multiple tenants.
 *
 * @see https://openid.net/specs/openid-connect-discovery-1_0.html
 */
test.describe('OpenID Connect Discovery', () => {

    test.beforeEach(async ({page}) => {
        const app = new Application(page)
        test.setTimeout(app.timeout)
    });

    test.describe('Endpoint Accessibility', () => {

        test('should be publicly accessible without authentication', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');

            expect(response.status()).toBe(200);
            expect(response.headers()['server']).toContain('Uitsmijter');
            expect(response.headers()['content-type']).toContain('application/json');
        });

        test('should include proper security headers', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');

            expect(response.status()).toBe(200);
            expect(response.headers()['x-content-type-options']).toBe('nosniff');
            expect(response.headers()['cache-control']).toContain('public');
            expect(response.headers()['cache-control']).toContain('max-age=3600');
        });

        test('should return valid JSON', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const json = await response.json();

            expect(json).toBeDefined();
            expect(typeof json).toBe('object');
        });
    });

    test.describe('Required Fields - OpenID Discovery Spec', () => {

        test('should include all required fields per OpenID Connect Discovery 1.0', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config = await response.json();

            // REQUIRED fields
            expect(config).toHaveProperty('issuer');
            expect(config).toHaveProperty('authorization_endpoint');
            expect(config).toHaveProperty('token_endpoint');
            expect(config).toHaveProperty('jwks_uri');
            expect(config).toHaveProperty('response_types_supported');
            expect(config).toHaveProperty('subject_types_supported');
            expect(config).toHaveProperty('id_token_signing_alg_values_supported');

            // Verify types
            expect(typeof config.issuer).toBe('string');
            expect(typeof config.authorization_endpoint).toBe('string');
            expect(typeof config.token_endpoint).toBe('string');
            expect(typeof config.jwks_uri).toBe('string');
            expect(Array.isArray(config.response_types_supported)).toBe(true);
            expect(Array.isArray(config.subject_types_supported)).toBe(true);
            expect(Array.isArray(config.id_token_signing_alg_values_supported)).toBe(true);
        });

        test('should have issuer as HTTPS URL without query or fragment', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config = await response.json();

            expect(config.issuer).toMatch(/^https:\/\//);
            expect(config.issuer).not.toContain('?');
            expect(config.issuer).not.toContain('#');
        });

        test('should have issuer matching the request host', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config = await response.json();

            expect(config.issuer).toBe('https://id.example.com');
        });
        
        test('should have issuer matching the request host (bnbc)', async ({page}) => {
            const response = await page.goto('https://login.bnbc.example/.well-known/openid-configuration');
            const config = await response.json();
            
            expect(config.issuer).toBe('https://login.bnbc.example');
         });

        test('should have properly formatted endpoint URLs', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config = await response.json();

            // All endpoints should be HTTPS URLs
            expect(config.authorization_endpoint).toMatch(/^https:\/\//);
            expect(config.token_endpoint).toMatch(/^https:\/\//);
            expect(config.jwks_uri).toMatch(/^https:\/\//);
            expect(config.userinfo_endpoint).toMatch(/^https:\/\//);

            // Endpoints should be under the issuer domain
            expect(config.authorization_endpoint).toContain('id.example.com');
            expect(config.token_endpoint).toContain('id.example.com');
            expect(config.jwks_uri).toContain('id.example.com');
        });

        test('should include standard OAuth/OIDC endpoints', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config = await response.json();

            expect(config.authorization_endpoint).toContain('/authorize');
            expect(config.token_endpoint).toContain('/token');
            expect(config.jwks_uri).toContain('/.well-known/jwks.json');
            expect(config.userinfo_endpoint).toContain('/token/info');
        });

        test('should include "code" in response_types_supported for authorization code flow', async ({page}) => {
            // Verify that the OpenID configuration advertises support for the authorization code flow
            // by checking that "code" is present in the response_types_supported array
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config = await response.json();

            expect(config.response_types_supported).toContain('code');
        });

        test('should use public subject identifiers', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config = await response.json();

            expect(config.subject_types_supported).toContain('public');
        });

        test('should support RS256 signing algorithm', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config = await response.json();

            expect(config.id_token_signing_alg_values_supported).toContain('RS256');
        });
    });

    test.describe('Recommended Fields', () => {

        test('should include recommended fields', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config = await response.json();

            // RECOMMENDED fields
            expect(config).toHaveProperty('userinfo_endpoint');
            expect(config).toHaveProperty('scopes_supported');
            expect(config).toHaveProperty('claims_supported');
        });

        test('should include standard OpenID scopes', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config = await response.json();

            expect(config.scopes_supported).toContain('openid');
            expect(config.scopes_supported).toContain('profile');
            expect(config.scopes_supported).toContain('email');
        });

        test('should include standard JWT claims', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config = await response.json();

            expect(config.claims_supported).toContain('sub');
            expect(config.claims_supported).toContain('iss');
            expect(config.claims_supported).toContain('aud');
            expect(config.claims_supported).toContain('exp');
            expect(config.claims_supported).toContain('iat');
        });
    });

    test.describe('Optional Fields', () => {

        test('should include grant types supported', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config = await response.json();

            expect(config).toHaveProperty('grant_types_supported');
            expect(config.grant_types_supported).toContain('authorization_code');
            expect(config.grant_types_supported).toContain('refresh_token');
        });

        test('should include token endpoint authentication methods', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config = await response.json();

            expect(config).toHaveProperty('token_endpoint_auth_methods_supported');
            expect(Array.isArray(config.token_endpoint_auth_methods_supported)).toBe(true);
        });

        test('should include PKCE code challenge methods', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config = await response.json();

            expect(config).toHaveProperty('code_challenge_methods_supported');
            expect(config.code_challenge_methods_supported).toContain('S256');
        });

        test('should include response modes', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config = await response.json();

            expect(config).toHaveProperty('response_modes_supported');
            expect(Array.isArray(config.response_modes_supported)).toBe(true);
        });
        
        test('should not include PLAIN code challenge methods', async ({page}) => {
            const response = await page.goto('https://login.bnbc.example/.well-known/openid-configuration');

            expect(await response.status()).toBe(200)
            const config = await response.json();
            
            expect(config).toHaveProperty('code_challenge_methods_supported');
            expect(config.code_challenge_methods_supported).toContain('S256');
            expect(config.code_challenge_methods_supported).not.toContain('plain');
        });
    });

    test.describe('Multi-Tenant Support', () => {

        // Note: In the e2e test environment, we primarily test with id.example.com
        // Ham and Goat tenants may not be fully configured in all test scenarios

        test('should work for id.example.com tenant', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config = await response.json();

            expect(response.status()).toBe(200);
            expect(config.issuer).toBe('https://id.example.com');
            expect(config.authorization_endpoint).toContain('id.example.com');
            expect(config.token_endpoint).toContain('id.example.com');
            expect(config.jwks_uri).toContain('id.example.com');
        });

        test('should have consistent structure across multiple requests', async ({page}) => {
            const response1 = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config1 = await response1.json();

            const response2 = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config2 = await response2.json();

            // Both requests should return identical configuration
            expect(config1).toEqual(config2);

            // Should have all the same keys
            const keys1 = Object.keys(config1).sort();
            const keys2 = Object.keys(config2).sort();
            expect(keys1).toEqual(keys2);
        });

        test('should have tenant-specific scopes', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config = await response.json();

            expect(response.status()).toBe(200);
            expect(Array.isArray(config.scopes_supported)).toBe(true);
            expect(config.scopes_supported.length).toBeGreaterThan(0);

            // Should include default scopes
            expect(config.scopes_supported).toContain('openid');
        });

        // Skip ham.test and goat.test tests for now as they may not be configured
        // in all e2e test environments. Multi-tenant functionality is tested
        // extensively in unit tests (OpenidConfigurationBuilderTest.swift)
        test.skip('should return different issuer for ham.test tenant (skipped - tenant may not be configured)', async ({page}) => {
            // This test is skipped because ham.test may not be configured in the e2e environment
            // Multi-tenant support is verified in unit tests
        });

        test.skip('should return different issuer for goat.test tenant (skipped - tenant may not be configured)', async ({page}) => {
            // This test is skipped because goat.test may not be configured in the e2e environment
            // Multi-tenant support is verified in unit tests
        });
    });

    test.describe('Tenant-Specific Configuration', () => {

        test('should include tenant privacy policy URL if configured', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config = await response.json();

            // If the tenant has privacy URL configured, it should be in op_policy_uri
            if (config.op_policy_uri) {
                expect(config.op_policy_uri).toMatch(/^https:\/\//);
            }
        });

        test('should aggregate scopes from all tenant clients', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config = await response.json();

            // Should have unique scopes (no duplicates)
            const scopes = config.scopes_supported;
            const uniqueScopes = [...new Set(scopes)];
            expect(scopes.length).toBe(uniqueScopes.length);

            // Should be sorted alphabetically
            const sortedScopes = [...scopes].sort();
            expect(scopes).toEqual(sortedScopes);
        });

        test('should aggregate grant types from all tenant clients', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config = await response.json();

            // Should have unique grant types (no duplicates)
            const grantTypes = config.grant_types_supported;
            const uniqueGrantTypes = [...new Set(grantTypes)];
            expect(grantTypes.length).toBe(uniqueGrantTypes.length);

            // Should be sorted alphabetically
            const sortedGrantTypes = [...grantTypes].sort();
            expect(grantTypes).toEqual(sortedGrantTypes);
        });
    });

    test.describe('Error Handling', () => {

        test.skip('should return error for non-existent tenant (skipped - DNS resolution)', async ({page}) => {
            // This test is skipped because nonexistent.invalid causes DNS resolution errors
            // Error handling is tested at the unit test level
            // In a real scenario, a non-configured tenant would return 400/404 from the server
        });
    });

    test.describe('JSON Format Compliance', () => {

        test('should return properly formatted JSON with no syntax errors', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const text = await response.text();

            expect(() => JSON.parse(text)).not.toThrow();
        });

        test('should not include null values for optional fields', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config = await response.json();

            // Check that if optional fields are present, they're not null
            if ('registration_endpoint' in config) {
                expect(config.registration_endpoint).not.toBeNull();
            }
            if ('op_tos_uri' in config) {
                expect(config.op_tos_uri).not.toBeNull();
            }
        });

        test('should have array fields as actual arrays', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config = await response.json();

            // All array fields should be arrays, not strings
            expect(Array.isArray(config.response_types_supported)).toBe(true);
            expect(Array.isArray(config.subject_types_supported)).toBe(true);
            expect(Array.isArray(config.id_token_signing_alg_values_supported)).toBe(true);
            expect(Array.isArray(config.scopes_supported)).toBe(true);
            expect(Array.isArray(config.claims_supported)).toBe(true);
            expect(Array.isArray(config.grant_types_supported)).toBe(true);
        });

        test('should have boolean fields as actual booleans', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config = await response.json();

            // Boolean fields should be booleans, not strings
            if ('claims_parameter_supported' in config) {
                expect(typeof config.claims_parameter_supported).toBe('boolean');
            }
            if ('request_parameter_supported' in config) {
                expect(typeof config.request_parameter_supported).toBe('boolean');
            }
            if ('request_uri_parameter_supported' in config) {
                expect(typeof config.request_uri_parameter_supported).toBe('boolean');
            }
        });
    });

    test.describe('Client Integration', () => {

        test('should allow OAuth clients to discover authorization endpoint', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config = await response.json();

            // A client should be able to construct authorization request from this
            expect(config.authorization_endpoint).toBeDefined();
            expect(config.response_types_supported).toBeDefined();
            expect(config.scopes_supported).toBeDefined();

            // Verify authorization URL is well-formed
            const url = new URL(config.authorization_endpoint);
            expect(url.protocol).toBe('https:');
            expect(url.pathname).toBe('/authorize');
        });

        test('should allow OAuth clients to discover token endpoint', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config = await response.json();

            // A client should be able to exchange codes for tokens
            expect(config.token_endpoint).toBeDefined();
            expect(config.grant_types_supported).toBeDefined();

            // Verify token URL is well-formed
            const url = new URL(config.token_endpoint);
            expect(url.protocol).toBe('https:');
            expect(url.pathname).toBe('/token');
        });

        test('should provide JWKS endpoint for token verification', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config = await response.json();

            expect(config.jwks_uri).toBeDefined();

            // Verify JWKS URL is well-formed
            const url = new URL(config.jwks_uri);
            expect(url.protocol).toBe('https:');
            expect(url.pathname).toBe('/.well-known/jwks.json');
        });
    });

    test.describe('Performance & Caching', () => {

        test('should respond quickly (under 1 second)', async ({page}) => {
            const startTime = Date.now();
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const endTime = Date.now();

            expect(response.status()).toBe(200);
            expect(endTime - startTime).toBeLessThan(1000);
        });

        test('should be cacheable', async ({page}) => {
            const response = await page.goto('https://id.example.com/.well-known/openid-configuration');

            expect(response.headers()['cache-control']).toBeDefined();
            expect(response.headers()['cache-control']).toContain('max-age');
        });

        test('should serve same configuration on repeated requests', async ({page}) => {
            const response1 = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config1 = await response1.json();

            const response2 = await page.goto('https://id.example.com/.well-known/openid-configuration');
            const config2 = await response2.json();

            expect(config1).toEqual(config2);
        });
    });
});
