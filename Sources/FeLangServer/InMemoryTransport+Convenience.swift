import Foundation

// MARK: - Convenience Methods

extension InMemoryTransport {

    /// Send an initialize request.
    public func sendInitialize() {
        let params: AnyCodableValue = .object([
            "processId": .null,
            "rootUri": .null,
            "capabilities": .object([:])
        ])
        sendToServer(JSONRPCRequest(id: .integer(0), method: "initialize", params: params))
    }

    /// Send a textDocument/didOpen notification.
    public func sendDidOpen(uri: String, content: String, languageId: String = "fe") {
        let params: AnyCodableValue = .object([
            "textDocument": .object([
                "uri": .string(uri),
                "languageId": .string(languageId),
                "version": .int(1),
                "text": .string(content)
            ])
        ])
        sendToServer(JSONRPCRequest(id: nil, method: "textDocument/didOpen", params: params))
    }

    /// Send a textDocument/didChange notification.
    public func sendDidChange(uri: String, version: Int, content: String) {
        let params: AnyCodableValue = .object([
            "textDocument": .object([
                "uri": .string(uri),
                "version": .int(version)
            ]),
            "contentChanges": .array([
                .object(["text": .string(content)])
            ])
        ])
        sendToServer(JSONRPCRequest(id: nil, method: "textDocument/didChange", params: params))
    }

    /// Send a textDocument/completion request.
    public func sendCompletion(id: RequestId, uri: String, line: Int, character: Int) {
        let params: AnyCodableValue = .object([
            "textDocument": .object(["uri": .string(uri)]),
            "position": .object([
                "line": .int(line),
                "character": .int(character)
            ])
        ])
        sendToServer(JSONRPCRequest(id: id, method: "textDocument/completion", params: params))
    }

    /// Send a textDocument/hover request.
    public func sendHover(id: RequestId, uri: String, line: Int, character: Int) {
        let params: AnyCodableValue = .object([
            "textDocument": .object(["uri": .string(uri)]),
            "position": .object([
                "line": .int(line),
                "character": .int(character)
            ])
        ])
        sendToServer(JSONRPCRequest(id: id, method: "textDocument/hover", params: params))
    }

    /// Send a shutdown request.
    public func sendShutdown(id: RequestId) {
        sendToServer(JSONRPCRequest(id: id, method: "shutdown"))
    }

    /// Send an exit notification.
    public func sendExit() {
        sendToServer(JSONRPCRequest(id: nil, method: "exit"))
    }
}
