@testable import FeLangServer
import Foundation
import Testing

// MARK: - InMemoryTransport Tests

struct InMemoryTransportTests {

    @Test func testBasicRequestResponse() async throws {
        let transport = InMemoryTransport()

        // Client sends a request
        await transport.sendToServer(JSONRPCRequest(id: .integer(1), method: "test"))

        // Server reads the request
        let request = try await transport.readRequest()
        #expect(request?.id == .integer(1))
        #expect(request?.method == "test")

        // Server sends a response
        let response = JSONRPCResponse.success(id: .integer(1), result: .string("ok"))
        try await transport.send(response)

        // Client receives the response
        var iterator = transport.output.makeAsyncIterator()
        let message = await iterator.next()
        if case .response(let received) = message {
            #expect(received.id == .integer(1))
            #expect(received.error == nil)
        } else {
            Issue.record("Expected .response, got \(String(describing: message))")
        }

        await transport.close()
    }

    @Test func testRequestBuffering() async throws {
        let transport = InMemoryTransport()

        // Send 3 requests before reading
        await transport.sendToServer(JSONRPCRequest(id: .integer(1), method: "first"))
        await transport.sendToServer(JSONRPCRequest(id: .integer(2), method: "second"))
        await transport.sendToServer(JSONRPCRequest(id: .integer(3), method: "third"))

        // Read them in order
        let req1 = try await transport.readRequest()
        let req2 = try await transport.readRequest()
        let req3 = try await transport.readRequest()

        #expect(req1?.method == "first")
        #expect(req2?.method == "second")
        #expect(req3?.method == "third")

        await transport.close()
    }

    @Test func testReadRequestSuspension() async throws {
        let transport = InMemoryTransport()

        // Start reading before any request is sent
        let readTask = Task {
            try await transport.readRequest()
        }

        // Small delay to ensure readRequest suspends
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Now send a request
        await transport.sendToServer(JSONRPCRequest(id: .integer(42), method: "delayed"))

        // The read should resolve
        let request = try await readTask.value
        #expect(request?.method == "delayed")
        #expect(request?.id == .integer(42))

        await transport.close()
    }

    @Test func testSendNotification() async throws {
        let transport = InMemoryTransport()

        try await transport.sendNotification(
            method: "textDocument/publishDiagnostics",
            params: .object(["uri": .string("file:///test.fe")])
        )

        var iterator = transport.output.makeAsyncIterator()
        let message = await iterator.next()
        if case .notification(let method, let params) = message {
            #expect(method == "textDocument/publishDiagnostics")
            #expect(params != nil)
        } else {
            Issue.record("Expected .notification, got \(String(describing: message))")
        }

        await transport.close()
    }

    @Test func testClose() async throws {
        let transport = InMemoryTransport()

        await transport.close()

        // readRequest should return nil after close
        let request = try await transport.readRequest()
        #expect(request == nil)
    }

    @Test func testCloseResumesWaitingReader() async throws {
        let transport = InMemoryTransport()

        // Start reading (will suspend)
        let readTask = Task {
            try await transport.readRequest()
        }

        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Close should resume the waiting reader with nil
        await transport.close()

        let request = try await readTask.value
        #expect(request == nil)
    }
}

// MARK: - ServerMessage Tests

struct ServerMessageTests {

    @Test func testResponseMessage() async throws {
        let transport = InMemoryTransport()

        let response = JSONRPCResponse.success(id: .integer(1), result: .string("result"))
        try await transport.send(response)

        var iterator = transport.output.makeAsyncIterator()
        let message = await iterator.next()

        if case .response(let received) = message {
            #expect(received.id == .integer(1))
        } else {
            Issue.record("Expected .response")
        }

        await transport.close()
    }

    @Test func testNotificationMessage() async throws {
        let transport = InMemoryTransport()

        try await transport.sendNotification(method: "test/notify", params: .bool(true))

        var iterator = transport.output.makeAsyncIterator()
        let message = await iterator.next()

        if case .notification(let method, let params) = message {
            #expect(method == "test/notify")
            #expect(params == .bool(true))
        } else {
            Issue.record("Expected .notification")
        }

        await transport.close()
    }
}

// MARK: - LanguageServer Integration Tests

struct LanguageServerIntegrationTests {

    @Test func testCreateInMemory() async throws {
        let (server, transport) = LanguageServer.createInMemory()

        let serverTask = Task {
            await server.run()
        }

        // Send initialize
        await transport.sendInitialize()

        // Read the response
        var iterator = transport.output.makeAsyncIterator()
        let message = await iterator.next()

        if case .response(let response) = message {
            #expect(response.id == .integer(0))
            #expect(response.error == nil)
            #expect(response.result != nil)
        } else {
            Issue.record("Expected .response for initialize, got \(String(describing: message))")
        }

        // Shutdown and exit
        await transport.sendShutdown(id: .integer(1))
        _ = await iterator.next() // consume shutdown response
        await transport.sendExit()
        await transport.close()
        serverTask.cancel()
    }

    @Test func testDidOpenPublishesDiagnostics() async throws {
        let (server, transport) = LanguageServer.createInMemory()

        let serverTask = Task {
            await server.run()
        }

        // Initialize
        await transport.sendInitialize()
        var iterator = transport.output.makeAsyncIterator()
        _ = await iterator.next() // consume initialize response

        // Send initialized notification
        await transport.sendToServer(JSONRPCRequest(id: nil, method: "initialized"))

        // Open a document with valid code
        await transport.sendDidOpen(uri: "file:///test.fe", content: "x: integer ← 42")

        // Should receive diagnostics notification
        let message = await iterator.next()
        if case .notification(let method, _) = message {
            #expect(method == "textDocument/publishDiagnostics")
        } else {
            Issue.record("Expected diagnostics notification, got \(String(describing: message))")
        }

        // Shutdown
        await transport.sendShutdown(id: .integer(2))
        _ = await iterator.next()
        await transport.sendExit()
        await transport.close()
        serverTask.cancel()
    }
}

// MARK: - Convenience Methods Tests

struct ConvenienceMethodsTests {

    @Test func testSendInitialize() async throws {
        let transport = InMemoryTransport()

        await transport.sendInitialize()

        let request = try await transport.readRequest()
        #expect(request?.method == "initialize")
        #expect(request?.id == .integer(0))
        #expect(request?.params != nil)

        await transport.close()
    }

    @Test func testSendDidOpen() async throws {
        let transport = InMemoryTransport()

        await transport.sendDidOpen(uri: "file:///test.fe", content: "hello")

        let request = try await transport.readRequest()
        #expect(request?.method == "textDocument/didOpen")
        #expect(request?.id == nil) // notification

        await transport.close()
    }

    @Test func testSendDidChange() async throws {
        let transport = InMemoryTransport()

        await transport.sendDidChange(uri: "file:///test.fe", version: 3, content: "updated")

        let request = try await transport.readRequest()
        #expect(request?.method == "textDocument/didChange")
        #expect(request?.id == nil) // notification
        #expect(request?.params != nil)

        await transport.close()
    }

    @Test func testSendCompletion() async throws {
        let transport = InMemoryTransport()

        await transport.sendCompletion(
            id: .integer(5),
            uri: "file:///test.fe",
            line: 0,
            character: 3
        )

        let request = try await transport.readRequest()
        #expect(request?.method == "textDocument/completion")
        #expect(request?.id == .integer(5))

        await transport.close()
    }

    @Test func testSendHover() async throws {
        let transport = InMemoryTransport()

        await transport.sendHover(
            id: .integer(6),
            uri: "file:///test.fe",
            line: 1,
            character: 5
        )

        let request = try await transport.readRequest()
        #expect(request?.method == "textDocument/hover")
        #expect(request?.id == .integer(6))

        await transport.close()
    }

    @Test func testSendShutdownAndExit() async throws {
        let transport = InMemoryTransport()

        await transport.sendShutdown(id: .integer(99))
        let shutdownReq = try await transport.readRequest()
        #expect(shutdownReq?.method == "shutdown")
        #expect(shutdownReq?.id == .integer(99))

        await transport.sendExit()
        let exitReq = try await transport.readRequest()
        #expect(exitReq?.method == "exit")
        #expect(exitReq?.id == nil)

        await transport.close()
    }
}
