import Foundation
import Testing
import VaporTesting
import Redis
@testable import Uitsmijter_AuthServer
@MainActor
@Suite struct AuthCodeStorageRedisTest {

    class RedisMock: RedisClient {
        private(set) var eventLoop: NIOCore.EventLoop
        private let storage = MemoryAuthCodeStorage()
        var commandStack: [String] = []

        init() {
            let evGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
            eventLoop = evGroup.any()
        }

        func send(command: String, with arguments: [RESPValue]) -> NIOCore.EventLoopFuture<RESPValue> {
            if command == "PING" {
                return eventLoop.future(RESPValue(from: "PONG"))
            }
            commandStack.append(command)

            // Handle commands that need specific return types
            switch command {
            case "SCAN":
                // SCAN returns [cursor, [keys...]]
                let emptyKeys: [String] = []
                let scanResult: [RESPValue] = [RESPValue(from: 0), RESPValue(from: emptyKeys)]
                return eventLoop.future(RESPValue(from: scanResult))
            case "DEL":
                // DEL returns number of keys deleted
                return eventLoop.future(RESPValue(from: 1))
            case "EXPIRE":
                // EXPIRE returns 1 for success
                return eventLoop.future(RESPValue(from: 1))
            default:
                return eventLoop.future(RESPValue(from: ""))
            }
        }

        func logging(to logger: Logger) -> RedisClient {
            self
        }

        // swiftlint:disable unavailable_function
        func unsubscribe(from channels: [RedisChannelName]) -> NIOCore.EventLoopFuture<()> {
            fatalError("unsubscribe(from:) has not been implemented")
        }

        func punsubscribe(from patterns: [String]) -> NIOCore.EventLoopFuture<()> {
            fatalError("punsubscribe(from:) has not been implemented")
        }

        // swiftlint:enable unavailable_function
    }

    func setupStorageWithApp() async throws -> (Application, AuthCodeStorage, RedisMock) {
        let temporaryDirectory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent(String.random(length: 10))

        let app = try await Application.make(.testing)
        app.directory.resourcesDirectory = temporaryDirectory.absoluteString
        try? configure(app)

        let mock = RedisMock()
        let storage = AuthCodeStorage(use: .redis(client: mock))

        let session_1 = AuthSession(
            type: .code,
            state: "state_1",
            code: Code(value: "code_1"),
            scopes: ["foo", "bar"],
            payload: nil,
            redirect: "",
            ttl: 10
        )
        let session_2 = AuthSession(
            type: .code,
            state: "state_2",
            code: Code(value: "code_2"),
            scopes: ["foo", "bar"],
            payload: nil,
            redirect: "",
            ttl: 50
        )
        let session_TTL = AuthSession(
            type: .code,
            state: "state_TTL",
            code: Code(value: "code_TTL"),
            scopes: [],
            payload: nil,
            redirect: "",
            ttl: 1
        )

        do {
            try await storage.set(authSession: session_1)
            #expect(mock.commandStack.count == 3)
            try await storage.set(authSession: session_2)
            #expect(mock.commandStack.count == 6)
            try await storage.set(authSession: session_TTL)
            #expect(mock.commandStack.count == 9)
        } catch {
            Issue.record("Error: \(error.localizedDescription)")
        }
        mock.commandStack = []

        return (app, storage, mock)
    }

    @Test func storeSessionsInRedisNil() async throws {
        let mock = RedisMock()
        let storage = AuthCodeStorage(use: .redis(client: mock))

        _ = await storage.get(type: .code, codeValue: "code_0")
        #expect(mock.commandStack[0] == "GET")
        #expect(mock.commandStack.count == 1)
    }

    @Test func storeSessionsInRedisGetRemoved() async throws {
        let mock = RedisMock()
        let storage = AuthCodeStorage(use: .redis(client: mock))

        let session_1 = AuthSession(
            type: .code,
            state: "state_1",
            code: Code(value: "code_1"),
            scopes: ["foo", "bar"],
            payload: nil,
            redirect: "",
            ttl: 10
        )
        try await storage.set(authSession: session_1)

        _ = await storage.get(type: .code, codeValue: "code_1", remove: true)
        // After set() with TTL: SET, EXPIRE, and SCAN (async from count() for metrics)
        // After get() with remove: GET, DEL
        // Note: SCAN happens asynchronously so order with GET may vary
        #expect(mock.commandStack[0] == "SET")
        #expect(mock.commandStack[1] == "EXPIRE")
        #expect(mock.commandStack.contains("SCAN"))
        #expect(mock.commandStack.contains("GET"))
        #expect(mock.commandStack.contains("DEL"))
        #expect(mock.commandStack.count == 5)
    }
}
