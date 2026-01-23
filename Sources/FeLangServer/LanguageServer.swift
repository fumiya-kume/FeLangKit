import Foundation
import FeLangCore

// MARK: - Language Server

/// FE Language Server implementation.
public actor LanguageServer {
    /// The transport for JSON-RPC communication
    private let transport: JSONRPCTransport

    /// Document storage
    private let documents: DocumentStore

    /// Diagnostics provider
    private let diagnosticsProvider: DiagnosticsProvider

    /// Completion provider
    private let completionProvider: CompletionProvider

    /// Hover provider
    private let hoverProvider: HoverProvider

    /// Definition provider
    private let definitionProvider: DefinitionProvider

    /// Server state
    private var initialized = false
    private var shutdownRequested = false

    // MARK: - Initialization

    public init(transport: JSONRPCTransport) {
        self.transport = transport
        self.documents = DocumentStore()
        self.diagnosticsProvider = DiagnosticsProvider()
        self.completionProvider = CompletionProvider()
        self.hoverProvider = HoverProvider()
        self.definitionProvider = DefinitionProvider()
    }

    /// Create a server with standard I/O transport.
    public static func createStdio() -> LanguageServer {
        LanguageServer(transport: StdioTransport())
    }

    // MARK: - Main Loop

    /// Run the language server.
    public func run() async {
        while !shutdownRequested {
            do {
                guard let request = try await transport.readRequest() else {
                    break // EOF
                }
                await handleRequest(request)
            } catch {
                // Log error but continue
                await sendErrorResponse(id: nil, error: .parseError)
            }
        }
    }

    // MARK: - Request Handling

    private func handleRequest(_ request: JSONRPCRequest) async {
        // Handle notifications (no id)
        if request.id == nil {
            await handleNotification(request)
            return
        }

        // Handle requests
        do {
            let result = try await handleMethod(request.method, params: request.params)
            await sendSuccessResponse(id: request.id, result: result)
        } catch let error as JSONRPCError {
            await sendErrorResponse(id: request.id, error: error)
        } catch {
            await sendErrorResponse(id: request.id, error: .serverError(error.localizedDescription))
        }
    }

    private func handleMethod(_ method: String, params: AnyCodableValue?) async throws -> AnyCodableValue? {
        switch method {
        case "initialize":
            return try await handleInitialize(params)
        case "shutdown":
            return try await handleShutdown()
        case "textDocument/completion":
            return try await handleCompletion(params)
        case "textDocument/hover":
            return try await handleHover(params)
        case "textDocument/definition":
            return try await handleDefinition(params)
        default:
            throw JSONRPCError.methodNotFound
        }
    }

    private func handleNotification(_ request: JSONRPCRequest) async {
        switch request.method {
        case "initialized":
            // Client confirmed initialization
            break
        case "exit":
            shutdownRequested = true
        case "textDocument/didOpen":
            await handleDidOpen(request.params)
        case "textDocument/didChange":
            await handleDidChange(request.params)
        case "textDocument/didClose":
            await handleDidClose(request.params)
        case "textDocument/didSave":
            await handleDidSave(request.params)
        default:
            // Unknown notification, ignore
            break
        }
    }

    // MARK: - Initialize

    private func handleInitialize(_ params: AnyCodableValue?) async throws -> AnyCodableValue? {
        initialized = true

        let capabilities = ServerCapabilities(
            textDocumentSync: TextDocumentSyncOptions(
                openClose: true,
                change: 1, // Full sync
                save: SaveOptions(includeText: true)
            ),
            completionProvider: CompletionOptions(
                triggerCharacters: [".", "(", ",", ":"],
                resolveProvider: false
            ),
            hoverProvider: true,
            definitionProvider: true,
            semanticTokensProvider: SemanticTokensOptions(
                legend: .default,
                full: true
            )
        )

        let result = InitializeResult(capabilities: capabilities)
        return try .from(result)
    }

    private func handleShutdown() async throws -> AnyCodableValue? {
        shutdownRequested = true
        return nil
    }

    // MARK: - Document Sync

    private func handleDidOpen(_ params: AnyCodableValue?) async {
        guard let params = params else { return }

        do {
            struct DidOpenParams: Codable {
                let textDocument: TextDocumentItem
            }
            let didOpen = try params.decode(DidOpenParams.self)
            let doc = didOpen.textDocument

            await documents.open(
                uri: doc.uri,
                languageId: doc.languageId,
                version: doc.version,
                content: doc.text
            )

            // Publish diagnostics
            await publishDiagnostics(uri: doc.uri)
        } catch {
            // Ignore malformed notifications
        }
    }

    private func handleDidChange(_ params: AnyCodableValue?) async {
        guard let params = params else { return }

        do {
            struct DidChangeParams: Codable {
                let textDocument: VersionedTextDocumentIdentifier
                let contentChanges: [ContentChange]
            }
            struct ContentChange: Codable {
                let text: String
            }

            let didChange = try params.decode(DidChangeParams.self)
            let doc = didChange.textDocument

            // Full sync - use the last content change
            if let lastChange = didChange.contentChanges.last {
                await documents.update(
                    uri: doc.uri,
                    version: doc.version,
                    content: lastChange.text
                )

                // Publish diagnostics
                await publishDiagnostics(uri: doc.uri)
            }
        } catch {
            // Ignore malformed notifications
        }
    }

    private func handleDidClose(_ params: AnyCodableValue?) async {
        guard let params = params else { return }

        do {
            struct DidCloseParams: Codable {
                let textDocument: TextDocumentIdentifier
            }
            let didClose = try params.decode(DidCloseParams.self)
            await documents.close(uri: didClose.textDocument.uri)
        } catch {
            // Ignore malformed notifications
        }
    }

    private func handleDidSave(_ params: AnyCodableValue?) async {
        guard let params = params else { return }

        do {
            struct DidSaveParams: Codable {
                let textDocument: TextDocumentIdentifier
                let text: String?
            }
            let didSave = try params.decode(DidSaveParams.self)
            let uri = didSave.textDocument.uri

            // If text is included, update the document
            if let text = didSave.text {
                await documents.update(uri: uri, version: 0, content: text)
            }

            // Publish diagnostics
            await publishDiagnostics(uri: uri)
        } catch {
            // Ignore malformed notifications
        }
    }

    // MARK: - Completion

    private func handleCompletion(_ params: AnyCodableValue?) async throws -> AnyCodableValue? {
        guard let params = params else { throw JSONRPCError.invalidParams }

        let completionParams = try params.decode(CompletionParams.self)
        let uri = completionParams.textDocument.uri

        guard var document = await documents.get(uri: uri) else {
            return try .from(CompletionList(isIncomplete: false, items: []))
        }

        let completions = completionProvider.complete(document: &document, position: completionParams.position)
        return try .from(completions)
    }

    // MARK: - Hover

    private func handleHover(_ params: AnyCodableValue?) async throws -> AnyCodableValue? {
        guard let params = params else { throw JSONRPCError.invalidParams }

        let hoverParams = try params.decode(HoverParams.self)
        let uri = hoverParams.textDocument.uri

        guard var document = await documents.get(uri: uri) else {
            return nil
        }

        if let hover = hoverProvider.hover(document: &document, position: hoverParams.position) {
            return try .from(hover)
        }
        return nil
    }

    // MARK: - Definition

    private func handleDefinition(_ params: AnyCodableValue?) async throws -> AnyCodableValue? {
        guard let params = params else { throw JSONRPCError.invalidParams }

        let defParams = try params.decode(DefinitionParams.self)
        let uri = defParams.textDocument.uri

        guard var document = await documents.get(uri: uri) else {
            return nil
        }

        if let location = definitionProvider.findDefinition(document: &document, position: defParams.position) {
            return try .from(location)
        }
        return nil
    }

    // MARK: - Diagnostics

    private func publishDiagnostics(uri: String) async {
        guard let document = await documents.get(uri: uri) else { return }

        let diagnostics = diagnosticsProvider.diagnose(document: document)
        let publishParams = PublishDiagnosticsParams(uri: uri, diagnostics: diagnostics)

        do {
            let params = try AnyCodableValue.from(publishParams)
            try await transport.sendNotification(method: "textDocument/publishDiagnostics", params: params)
        } catch {
            // Ignore send errors
        }
    }

    // MARK: - Response Helpers

    private func sendSuccessResponse(id: RequestId?, result: AnyCodableValue?) async {
        let response = JSONRPCResponse.success(id: id, result: result)
        do {
            try await transport.send(response)
        } catch {
            // Ignore send errors
        }
    }

    private func sendErrorResponse(id: RequestId?, error: JSONRPCError) async {
        let response = JSONRPCResponse.error(id: id, error: error)
        do {
            try await transport.send(response)
        } catch {
            // Ignore send errors
        }
    }
}
