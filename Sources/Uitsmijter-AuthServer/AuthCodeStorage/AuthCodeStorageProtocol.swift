import Foundation

/// Protocol for storing and retrieving authorization code sessions
/// All implementations should be actors to ensure thread-safe access
protocol AuthCodeStorageProtocol: Sendable {
    /// Store an authorization session
    func set(authSession: AuthSession) async throws

    /// Retrieve an authorization session by type and code value
    func get(type: AuthSession.CodeType, codeValue: String, remove: Bool?) async -> AuthSession?

    /// Push a login session
    func push(loginId: LoginSession) async throws

    /// Pull and remove a login session by UUID
    func pull(loginUuid: UUID) async -> Bool

    /// Count the number of stored sessions
    func count() async -> Int

    /// Delete a specific session by type and code value
    func delete(type: AuthSession.CodeType, codeValue: String) async throws

    /// Wipe all sessions for a specific tenant and subject
    func wipe(tenant: Tenant, subject: String) async

    /// Count sessions for a specific tenant and type
    /// - Parameters:
    ///   - tenant: The tenant to count sessions for
    ///   - type: The type of sessions to count (defaults to .refresh for long-lived sessions)
    /// - Returns: The number of sessions matching the criteria
    func count(tenant: Tenant, type: AuthSession.CodeType) async -> Int

    /// Check if the storage is healthy
    func isHealthy() async -> Bool
}
