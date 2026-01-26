import Foundation

// MARK: - Server Message

/// Message sent from the language server to the client.
public enum ServerMessage: Sendable {
    /// A response to a client request.
    case response(JSONRPCResponse)
    /// A server-initiated notification.
    case notification(method: String, params: AnyCodableValue?)
}

// MARK: - In-Memory Transport

/// JSON-RPC transport for in-process communication.
///
/// Use this transport when stdin/stdout is unavailable,
/// such as iOS apps embedding the language server.
public actor InMemoryTransport: JSONRPCTransport {
    private var pendingRequests: [JSONRPCRequest] = []
    private var requestWaiter: CheckedContinuation<JSONRPCRequest?, Never>?
    private var isClosed = false

    private let outputContinuation: AsyncStream<ServerMessage>.Continuation

    /// Async sequence of messages sent by the server.
    public nonisolated let output: AsyncStream<ServerMessage>

    public init() {
        var continuation: AsyncStream<ServerMessage>.Continuation!
        self.output = AsyncStream { cont in
            continuation = cont
        }
        self.outputContinuation = continuation
    }

    // MARK: - JSONRPCTransport

    public func send(_ response: JSONRPCResponse) async throws {
        outputContinuation.yield(.response(response))
    }

    public func sendNotification(method: String, params: AnyCodableValue?) async throws {
        outputContinuation.yield(.notification(method: method, params: params))
    }

    public func readRequest() async throws -> JSONRPCRequest? {
        if isClosed { return nil }
        if !pendingRequests.isEmpty {
            return pendingRequests.removeFirst()
        }
        precondition(requestWaiter == nil, "Concurrent readRequest() calls are not supported")
        return await withCheckedContinuation { continuation in
            requestWaiter = continuation
        }
    }

    // MARK: - Client API

    /// Send a request from the client to the server.
    public func sendToServer(_ request: JSONRPCRequest) {
        guard !isClosed else { return }
        if let waiter = requestWaiter {
            requestWaiter = nil
            waiter.resume(returning: request)
        } else {
            pendingRequests.append(request)
        }
    }

    /// Close the transport.
    public func close() {
        isClosed = true
        pendingRequests.removeAll()
        if let waiter = requestWaiter {
            requestWaiter = nil
            waiter.resume(returning: nil)
        }
        outputContinuation.finish()
    }
}
