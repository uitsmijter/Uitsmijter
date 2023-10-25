import Foundation
import XCTVapor
import Redis
@testable import Server

final class AuthCodeStorageRedisTest: XCTestCase {
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
            return eventLoop.future(RESPValue(from: ""))
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

    let mock = RedisMock()
    var storage: AuthCodeStorage?

    override func setUp() {
        storage = AuthCodeStorage(use: .redis(client: mock))

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
            guard let storage else {
                XCTFail("No storage")
                return
            }
            try storage.set(authSession: session_1)
            XCTAssertEqual(mock.commandStack.count, 3)
            try storage.set(authSession: session_2)
            XCTAssertEqual(mock.commandStack.count, 6)
            try storage.set(authSession: session_TTL)
            XCTAssertEqual(mock.commandStack.count, 9)
        } catch {
            XCTFail("Error: \(error.localizedDescription)")
        }
        mock.commandStack = []
    }

    func testStoreSessionsInRedisNil() async throws {
        guard let storage else {
            throw TestError.fail(withError: "No storage available")
        }
        _ = storage.get(type: .code, codeValue: "code_0")
        XCTAssertEqual(mock.commandStack[0], "GET")
        XCTAssertEqual(mock.commandStack.count, 1)
    }

    func testStoreSessionsInRedisGetRemoved() async throws {
        guard let storage else {
            throw TestError.fail(withError: "No storage available")
        }
        _ = storage.get(type: .code, codeValue: "code_1", remove: true)
        XCTAssertEqual(mock.commandStack[0], "GET")
        XCTAssertEqual(mock.commandStack[1], "DEL")
    }
}
