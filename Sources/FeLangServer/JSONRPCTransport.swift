import Foundation

// MARK: - JSON-RPC Types

/// JSON-RPC message ID (can be integer or string).
public enum RequestId: Codable, Equatable, Sendable, Hashable {
    case integer(Int)
    case string(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .integer(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(
                RequestId.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected Int or String for request ID"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .integer(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        }
    }
}

/// JSON-RPC request message.
public struct JSONRPCRequest: Codable, Sendable {
    /// JSON-RPC version (always "2.0")
    public let jsonrpc: String
    /// Request ID (optional for notifications)
    public let id: RequestId?
    /// Method name
    public let method: String
    /// Parameters (optional)
    public let params: AnyCodableValue?

    public init(id: RequestId?, method: String, params: AnyCodableValue? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }
}

/// JSON-RPC response message.
public struct JSONRPCResponse: Codable, Sendable {
    /// JSON-RPC version (always "2.0")
    public let jsonrpc: String
    /// Request ID
    public let id: RequestId?
    /// Result (for successful responses)
    public let result: AnyCodableValue?
    /// Error (for error responses)
    public let error: JSONRPCError?

    public init(id: RequestId?, result: AnyCodableValue?, error: JSONRPCError? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = result
        self.error = error
    }

    public static func success(id: RequestId?, result: AnyCodableValue?) -> JSONRPCResponse {
        JSONRPCResponse(id: id, result: result, error: nil)
    }

    public static func error(id: RequestId?, error: JSONRPCError) -> JSONRPCResponse {
        JSONRPCResponse(id: id, result: nil, error: error)
    }
}

/// JSON-RPC error object.
public struct JSONRPCError: Error, Codable, Sendable {
    /// Error code
    public let code: Int
    /// Error message
    public let message: String
    /// Additional data (optional)
    public let data: AnyCodableValue?

    public init(code: Int, message: String, data: AnyCodableValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    // Standard error codes
    public static let parseError = JSONRPCError(code: -32700, message: "Parse error")
    public static let invalidRequest = JSONRPCError(code: -32600, message: "Invalid Request")
    public static let methodNotFound = JSONRPCError(code: -32601, message: "Method not found")
    public static let invalidParams = JSONRPCError(code: -32602, message: "Invalid params")
    public static let internalError = JSONRPCError(code: -32603, message: "Internal error")

    public static func serverError(_ message: String) -> JSONRPCError {
        JSONRPCError(code: -32000, message: message)
    }
}

// MARK: - AnyCodable Value

/// A type-erased Codable value for JSON-RPC params and results.
public enum AnyCodableValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodableValue])
    case object([String: AnyCodableValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let arrayValue = try? container.decode([AnyCodableValue].self) {
            self = .array(arrayValue)
        } else if let objectValue = try? container.decode([String: AnyCodableValue].self) {
            self = .object(objectValue)
        } else {
            throw DecodingError.typeMismatch(
                AnyCodableValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot decode AnyCodableValue"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }

    /// Decode params as a specific type.
    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let data = try JSONEncoder().encode(self)
        return try JSONDecoder().decode(type, from: data)
    }
}

// MARK: - Transport Protocol

/// Protocol for JSON-RPC transport.
public protocol JSONRPCTransport: Sendable {
    /// Send a response message.
    func send(_ response: JSONRPCResponse) async throws

    /// Send a notification.
    func sendNotification(method: String, params: AnyCodableValue?) async throws

    /// Read the next request.
    func readRequest() async throws -> JSONRPCRequest?
}

// MARK: - Standard I/O Transport

#if !os(iOS) && !os(tvOS) && !os(watchOS)
/// JSON-RPC transport using stdin/stdout.
public actor StdioTransport: JSONRPCTransport {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var inputBuffer = Data()

    public init() {}

    public func send(_ response: JSONRPCResponse) async throws {
        let data = try encoder.encode(response)
        try await writeMessage(data)
    }

    public func sendNotification(method: String, params: AnyCodableValue?) async throws {
        let request = JSONRPCRequest(id: nil, method: method, params: params)
        let data = try encoder.encode(request)
        try await writeMessage(data)
    }

    public func readRequest() async throws -> JSONRPCRequest? {
        guard let messageData = try await readMessage() else {
            return nil
        }
        return try decoder.decode(JSONRPCRequest.self, from: messageData)
    }

    // MARK: - Private Methods

    private func writeMessage(_ data: Data) async throws {
        let header = "Content-Length: \(data.count)\r\n\r\n"
        guard let headerData = header.data(using: .utf8) else {
            throw JSONRPCError.internalError
        }

        FileHandle.standardOutput.write(headerData)
        FileHandle.standardOutput.write(data)
    }

    private func readMessage() async throws -> Data? {
        // Read headers
        var contentLength: Int?

        while true {
            guard let line = readLine() else {
                return nil
            }

            if line.isEmpty {
                break
            }

            if line.lowercased().hasPrefix("content-length:") {
                let lengthString = line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
                contentLength = Int(lengthString)
            }
        }

        guard let length = contentLength else {
            throw JSONRPCError.parseError
        }

        // Read content
        var content = Data()
        while content.count < length {
            let remainingBytes = length - content.count
            if let chunk = FileHandle.standardInput.readData(ofLength: remainingBytes) as Data? {
                if chunk.isEmpty {
                    return nil // EOF
                }
                content.append(chunk)
            }
        }

        return content
    }

    private func readLine() -> String? {
        var line = ""
        while true {
            let data = FileHandle.standardInput.readData(ofLength: 1)
            guard !data.isEmpty, let char = String(data: data, encoding: .utf8) else {
                return line.isEmpty ? nil : line
            }

            if char == "\n" {
                return line.trimmingCharacters(in: CharacterSet(charactersIn: "\r"))
            }
            line.append(char)
        }
    }
}
#endif

// MARK: - Codable Extensions

extension AnyCodableValue {
    /// Create from any Encodable value.
    public static func from<T: Encodable>(_ value: T) throws -> AnyCodableValue {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(AnyCodableValue.self, from: data)
    }
}
