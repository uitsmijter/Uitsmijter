# Logger

A Swift logging framework for the Uitsmijter project that provides structured, configurable, and thread-safe logging capabilities with support for multiple output formats and audit trails.

## Overview

The Logger module is a custom logging implementation built on top of the [Swift Logging API](https://github.com/apple/swift-log). It provides:

- **Multiple Log Levels**: debug, info, notice, warning, error, critical
- **Flexible Output Formats**: Console (human-readable) and NDJSON (machine-readable)
- **Audit Logging**: Separate audit log stream for security and compliance events
- **Request Context**: Automatic correlation of logs with request IDs
- **Log History**: Circular buffer storing the last 250 log messages for debugging
- **Environment Configuration**: Control log level and format via environment variables
- **Thread Safety**: Full Swift 6 concurrency support

## Quick Start

### Basic Logging

```swift
import Logger

// Simple logging
Log.info("Server started successfully")

// With request context
Log.debug("Processing authentication", requestId: req.id)

// Different severity levels
Log.error("Database connection failed: \(error)")
Log.critical("System shutdown initiated")
```

### Audit Logging

For security-sensitive events that require audit trails:

```swift
Log.audit.info("User authentication successful", metadata: [
    "user_id": "\(userId)",
    "client_id": "\(clientId)",
    "ip_address": "\(ipAddress)"
])
```

### Integration with Libraries

Pass the logger to external libraries that accept Swift Logger:

```swift
// Vapor framework
app.logger = Log.shared

// AWS SDK
let s3Client = AWSClient(logger: Log.shared)

// Kubernetes client
let kubeClient = KubernetesClient(logger: Log.shared)
```

## Configuration

### Environment Variables

Configure logging behavior through environment variables:

| Variable | Values | Default | Description |
|----------|--------|---------|-------------|
| `LOG_LEVEL` | `debug`, `info`, `notice`, `warning`, `error`, `critical` | `info` | Minimum log level to output |
| `LOG_FORMAT` | `console`, `json` | `console` | Output format for log messages |

**Examples:**

```bash
# Debug level with console output (development)
LOG_LEVEL=debug LOG_FORMAT=console ./Uitsmijter

# Info level with JSON output (production)
LOG_LEVEL=info LOG_FORMAT=json ./Uitsmijter

# Error level with JSON output (production with reduced verbosity)
LOG_LEVEL=error LOG_FORMAT=json ./Uitsmijter
```

### Log Levels

From most to least verbose:

1. **debug** - Detailed diagnostic information for development and troubleshooting
2. **info** - General informational messages about application state and progress (default)
3. **notice** - Significant events that are more important than info but not problematic
4. **warning** - Potentially problematic situations that don't prevent operation
5. **error** - Failures that prevent specific operations but allow continued execution
6. **critical** - Severe errors that may lead to application failure or data loss

### Log Formats

#### Console Format

Human-readable format suitable for development and local debugging:

```
2025-10-17T09:30:45+0200 INFO: Server started successfully | main() in Main.swift:42
2025-10-17T09:30:46+0200 DEBUG: Processing authentication for user@example.com | authenticate(_:) in AuthController.swift:125
2025-10-17T09:30:47+0200 ERROR: Database connection failed: timeout after 30s | connect() in DatabasePool.swift:78
```

#### JSON Format (NDJSON)

Machine-readable newline-delimited JSON format for log aggregation and monitoring:

```json
{"level":"INFO","message":"Server started successfully","source":"Main","file":"Main.swift","function":"main()","line":42,"date":"2025-10-17T07:30:45Z"}
{"level":"DEBUG","message":"Processing authentication for user@example.com","source":"Server","file":"AuthController.swift","function":"authenticate(_:)","line":125,"date":"2025-10-17T07:30:46Z","metadata":{"request":"3B7A9C2E-1F4D-4B8A-9E2C-5D6F7A8B9C0D"}}
{"level":"ERROR","message":"Database connection failed: timeout after 30s","source":"Server","file":"DatabasePool.swift","function":"connect()","line":78,"date":"2025-10-17T07:30:47Z"}
```

## Architecture

### Core Components

#### `Log` Struct

The main entry point for all logging operations. Provides:
- Static logging methods for all log levels
- Automatic request context enrichment
- Shared logger instance for library integration
- Separate audit logger for compliance

#### `LogWriter` Struct

Custom `LogHandler` implementation that:
- Formats log messages for console or JSON output
- Maintains circular buffer of recent logs (last 250 messages)
- Filters common/noisy messages
- Provides thread-safe logging operations

#### `CircularBuffer<Element>`

Thread-safe fixed-size ring buffer for storing recent log messages:
- Capacity: 250 messages
- Automatic overflow handling (oldest messages are replaced)
- Concurrent read/write support using locks and semaphores

#### Extensions

- **`Logger.Level`**: String initialization and name property for configuration
- **`Date`**: RFC 1123 formatting for log timestamps
- **`JSONEncoder.main`**: Shared encoder with consistent configuration

## Usage Examples

### Request Context Logging

Automatically correlate logs with HTTP requests:

```swift
func handleRequest(_ req: Request) async throws -> Response {
    Log.info("Received login request", requestId: req.id)

    do {
        let user = try await authenticate(req)
        Log.info("Authentication successful for \(user.email)", requestId: req.id)
        return Response.ok
    } catch {
        Log.error("Authentication failed: \(error)", requestId: req.id)
        throw error
    }
}
```

### Audit Trail Logging

Track security-sensitive operations:

```swift
func grantAccess(user: User, resource: Resource) {
    Log.audit.info("Access granted", metadata: [
        "user_id": "\(user.id)",
        "user_email": "\(user.email)",
        "resource": "\(resource.path)",
        "action": "read",
        "ip_address": "\(user.ipAddress)",
        "timestamp": "\(Date().iso8601)"
    ])
}

func failedLoginAttempt(username: String, ipAddress: String) {
    Log.audit.warning("Failed login attempt", metadata: [
        "username": "\(username)",
        "ip_address": "\(ipAddress)",
        "attempt_count": "3",
        "locked": "true"
    ])
}
```

### Multiline Messages

Automatically sanitized to single line:

```swift
Log.debug("""
    User authentication details:
    - Email: \(email)
    - Tenant: \(tenant)
    - Client: \(client)
    - Scopes: \(scopes.joined(separator: ", "))
    """, requestId: req.id)

// Output: "User authentication details: - Email: user@example.com - Tenant: acme ..."
```

### Error Handling

Log errors with full context:

```swift
do {
    try await performDatabaseOperation()
} catch let error as DatabaseError {
    Log.error("Database operation failed: \(error.localizedDescription)")
    Log.debug("Database error details: \(error.debugDescription)")
} catch {
    Log.critical("Unexpected error in database operation: \(error)")
}
```

## Testing Support

### Accessing Log History

For testing purposes, the circular buffer stores recent log messages:

```swift
import Logger

// In your tests
func testLoggingBehavior() {
    // Perform some operation that logs
    someFunction()

    // Check the last log message
    let lastLog = LogWriter.lastLog
    assert(lastLog?.message.contains("Expected message") == true)
    assert(lastLog?.level == "INFO")

    // Check the log buffer
    let logCount = LogWriter.logBuffer.count
    assert(logCount >= 1)
}
```

### Log Message Structure

Each log message in the buffer contains:

```swift
public struct LogMessage: Encodable {
    public var level: String           // "DEBUG", "INFO", "ERROR", etc.
    public let message: String         // The log message content
    public var metadata: [String: String]?  // Additional context
    public let source: String?         // Module/component name
    public let file: String?           // Source file
    public let function: String?       // Function name
    public let line: UInt?            // Line number
    public let date: Date             // Timestamp
}
```

## Thread Safety

The Logger module is fully compatible with Swift 6 strict concurrency:

- **`Log`**: Marked as `Sendable`, safe to access from any isolation domain
- **`LogWriter`**: Uses `nonisolated(unsafe)` for static storage with thread-safe operations
- **`CircularBuffer`**: Implements internal locking for concurrent access
- **SwiftLog Integration**: The underlying `Logger` type is thread-safe by design

## Best Practices

### 1. Choose Appropriate Log Levels

```swift
// ✓ Good - Informational about normal operations
Log.info("User session created")

// ✗ Bad - Too verbose for production
Log.info("Entering function validateToken()")

// ✓ Good - Debug details useful for troubleshooting
Log.debug("Token validation: checking signature with key \(keyId)")

// ✓ Good - Warn about recoverable issues
Log.warning("Redis connection failed, using in-memory storage")

// ✓ Good - Error for failed operations
Log.error("Failed to send notification email: \(error)")

// ✓ Good - Critical for system-level failures
Log.critical("Unable to load required configuration, exiting")
```

### 2. Use Request Context

Always include request IDs when logging within request handlers:

```swift
// ✓ Good - Allows correlation across request lifecycle
Log.info("Starting OAuth authorization flow", requestId: req.id)

// ✗ Bad - Missing context makes debugging difficult
Log.info("Starting OAuth authorization flow")
```

### 3. Audit Security Events

Use the audit logger for security-relevant operations:

```swift
// ✓ Good - Audit trail for compliance
Log.audit.info("Password reset requested", metadata: [
    "user_email": "\(email)",
    "ip_address": "\(ip)"
])

// ✗ Bad - Security event in regular log
Log.info("Password reset requested for \(email)")
```

### 4. Include Relevant Context

```swift
// ✓ Good - Includes error details
Log.error("Failed to load tenant '\(tenantName)': \(error.localizedDescription)")

// ✗ Bad - Generic message without context
Log.error("Failed to load tenant")
```

### 5. Avoid Logging Sensitive Data

```swift
// ✓ Good - Redacted sensitive information
Log.info("User authenticated: email=\(email)")

// ✗ Bad - Logs password in plain text
Log.debug("Authentication attempt: email=\(email), password=\(password)")

// ✓ Good - Use audit log for sensitive operations
Log.audit.warning("Failed login attempt", metadata: [
    "username": "\(email)",
    "reason": "invalid_password"
])
```

## Performance Considerations

1. **Log Level Filtering**: Messages below the configured level are discarded early
2. **Lazy Evaluation**: Log messages are only formatted if they will be output
3. **Circular Buffer**: Fixed-size buffer prevents unbounded memory growth
4. **Message Filtering**: Common noisy messages are silently skipped
5. **Newline Sanitization**: Automatic conversion to single line for structured logs

## Dependencies

- **Swift Logging** (`swift-log`): Apple's standard logging API
- **Swift 6.2**: Required for concurrency support

## Files

- **`Log.swift`** - Main logging facade with static methods
- **`LogWriter.swift`** - Custom log handler implementation
- **`CircularBuffer.swift`** - Thread-safe ring buffer for log history
- **`Logger+Extensions.swift`** - Extensions for Logger.Level and Date
- **`JSONEncoder+main.swift`** - Shared JSON encoder configuration
- **`Metadata+Dictionary.swift`** - Placeholder for future metadata extensions

## Related Documentation

- [Swift Logging API Documentation](https://github.com/apple/swift-log)
- [Uitsmijter Main Documentation](https://docs.uitsmijter.io)
- [CLAUDE.md](../../CLAUDE.md) - Project-wide development guidelines
