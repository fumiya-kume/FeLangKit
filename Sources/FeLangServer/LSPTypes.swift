import Foundation

// MARK: - Basic LSP Types

/// Represents a position in a text document (zero-indexed line and character).
public struct Position: Codable, Equatable, Sendable {
    /// Zero-indexed line number
    public let line: Int
    /// Zero-indexed character offset (UTF-16 code units)
    public let character: Int

    public init(line: Int, character: Int) {
        self.line = line
        self.character = character
    }
}

/// Represents a range in a text document.
public struct Range: Codable, Equatable, Sendable {
    /// The range's start position
    public let start: Position
    /// The range's end position
    public let end: Position

    public init(start: Position, end: Position) {
        self.start = start
        self.end = end
    }

    public init(startLine: Int, startCharacter: Int, endLine: Int, endCharacter: Int) {
        self.start = Position(line: startLine, character: startCharacter)
        self.end = Position(line: endLine, character: endCharacter)
    }
}

/// Represents a location inside a resource.
public struct Location: Codable, Equatable, Sendable {
    /// The text document's URI
    public let uri: String
    /// The location's range
    public let range: Range

    public init(uri: String, range: Range) {
        self.uri = uri
        self.range = range
    }
}

/// Represents a text document identifier.
public struct TextDocumentIdentifier: Codable, Equatable, Sendable {
    /// The text document's URI
    public let uri: String

    public init(uri: String) {
        self.uri = uri
    }
}

/// Represents a versioned text document identifier.
public struct VersionedTextDocumentIdentifier: Codable, Equatable, Sendable {
    /// The text document's URI
    public let uri: String
    /// The version number
    public let version: Int

    public init(uri: String, version: Int) {
        self.uri = uri
        self.version = version
    }
}

/// Represents a text document item (full content).
public struct TextDocumentItem: Codable, Equatable, Sendable {
    /// The text document's URI
    public let uri: String
    /// The text document's language identifier
    public let languageId: String
    /// The version number
    public let version: Int
    /// The content of the opened text document
    public let text: String

    public init(uri: String, languageId: String, version: Int, text: String) {
        self.uri = uri
        self.languageId = languageId
        self.version = version
        self.text = text
    }
}

// MARK: - Diagnostics

/// Diagnostic severity levels.
public enum DiagnosticSeverity: Int, Codable, Sendable {
    case error = 1
    case warning = 2
    case information = 3
    case hint = 4
}

/// Represents a diagnostic (error, warning, etc.).
public struct Diagnostic: Codable, Equatable, Sendable {
    /// The range at which the diagnostic applies
    public let range: Range
    /// The diagnostic's severity
    public let severity: DiagnosticSeverity?
    /// The diagnostic's code (optional)
    public let code: String?
    /// A human-readable string describing the source
    public let source: String?
    /// The diagnostic's message
    public let message: String

    public init(
        range: Range,
        severity: DiagnosticSeverity? = nil,
        code: String? = nil,
        source: String? = nil,
        message: String
    ) {
        self.range = range
        self.severity = severity
        self.code = code
        self.source = source
        self.message = message
    }
}

// MARK: - Completion

/// Completion item kinds.
public enum CompletionItemKind: Int, Codable, Sendable {
    case text = 1
    case method = 2
    case function = 3
    case constructor = 4
    case field = 5
    case variable = 6
    case classKind = 7
    case interface = 8
    case module = 9
    case property = 10
    case unit = 11
    case value = 12
    case enumCase = 13
    case keyword = 14
    case snippet = 15
    case color = 16
    case file = 17
    case reference = 18
    case folder = 19
    case enumMember = 20
    case constant = 21
    case structKind = 22
    case event = 23
    case operatorKind = 24
    case typeParameter = 25
}

/// Represents a completion item.
public struct CompletionItem: Codable, Equatable, Sendable {
    /// The label of this completion item
    public let label: String
    /// The kind of this completion item
    public let kind: CompletionItemKind?
    /// A human-readable string with additional information
    public let detail: String?
    /// A human-readable string that represents a doc-comment
    public let documentation: String?
    /// A string that should be inserted when selecting this item
    public let insertText: String?

    public init(
        label: String,
        kind: CompletionItemKind? = nil,
        detail: String? = nil,
        documentation: String? = nil,
        insertText: String? = nil
    ) {
        self.label = label
        self.kind = kind
        self.detail = detail
        self.documentation = documentation
        self.insertText = insertText
    }
}

/// Represents a list of completion items.
public struct CompletionList: Codable, Equatable, Sendable {
    /// This list is not complete. Further typing should result in recomputing.
    public let isIncomplete: Bool
    /// The completion items
    public let items: [CompletionItem]

    public init(isIncomplete: Bool, items: [CompletionItem]) {
        self.isIncomplete = isIncomplete
        self.items = items
    }
}

// MARK: - Hover

/// Represents the content of a hover response.
public struct MarkupContent: Codable, Equatable, Sendable {
    /// The type of the content (plaintext or markdown)
    public let kind: String
    /// The content itself
    public let value: String

    public init(kind: String = "markdown", value: String) {
        self.kind = kind
        self.value = value
    }

    public static func plaintext(_ value: String) -> MarkupContent {
        MarkupContent(kind: "plaintext", value: value)
    }

    public static func markdown(_ value: String) -> MarkupContent {
        MarkupContent(kind: "markdown", value: value)
    }
}

/// Represents a hover response.
public struct Hover: Codable, Equatable, Sendable {
    /// The hover's content
    public let contents: MarkupContent
    /// An optional range
    public let range: Range?

    public init(contents: MarkupContent, range: Range? = nil) {
        self.contents = contents
        self.range = range
    }
}

// MARK: - Text Edits

/// Represents a text edit.
public struct TextEdit: Codable, Equatable, Sendable {
    /// The range of the text document to be manipulated
    public let range: Range
    /// The string to be inserted
    public let newText: String

    public init(range: Range, newText: String) {
        self.range = range
        self.newText = newText
    }
}

// MARK: - Semantic Tokens

/// Semantic token types.
public enum SemanticTokenType: String, CaseIterable, Codable, Sendable {
    case namespace
    case type
    case classType = "class"
    case enumType = "enum"
    case interface
    case structType = "struct"
    case typeParameter
    case parameter
    case variable
    case property
    case enumMember
    case event
    case function
    case method
    case macro
    case keyword
    case modifier
    case comment
    case string
    case number
    case regexp
    case operatorToken = "operator"
}

/// Semantic token modifiers.
public enum SemanticTokenModifier: String, CaseIterable, Codable, Sendable {
    case declaration
    case definition
    case readonly
    case staticModifier = "static"
    case deprecated
    case abstractModifier = "abstract"
    case asyncModifier = "async"
    case modification
    case documentation
    case defaultLibrary
}

/// Semantic tokens legend.
public struct SemanticTokensLegend: Codable, Equatable, Sendable {
    /// The token types
    public let tokenTypes: [String]
    /// The token modifiers
    public let tokenModifiers: [String]

    public init(tokenTypes: [String], tokenModifiers: [String]) {
        self.tokenTypes = tokenTypes
        self.tokenModifiers = tokenModifiers
    }

    public static let `default` = SemanticTokensLegend(
        tokenTypes: SemanticTokenType.allCases.map { $0.rawValue },
        tokenModifiers: SemanticTokenModifier.allCases.map { $0.rawValue }
    )
}

/// Semantic tokens response.
public struct SemanticTokens: Codable, Equatable, Sendable {
    /// The actual tokens data
    public let data: [Int]

    public init(data: [Int]) {
        self.data = data
    }
}

// MARK: - Server Capabilities

/// Server capabilities structure.
public struct ServerCapabilities: Codable, Sendable {
    /// Defines how text documents are synced
    public let textDocumentSync: TextDocumentSyncOptions?
    /// The server provides completion support
    public let completionProvider: CompletionOptions?
    /// The server provides hover support
    public let hoverProvider: Bool?
    /// The server provides go to definition support
    public let definitionProvider: Bool?
    /// The server provides semantic tokens support
    public let semanticTokensProvider: SemanticTokensOptions?

    public init(
        textDocumentSync: TextDocumentSyncOptions? = nil,
        completionProvider: CompletionOptions? = nil,
        hoverProvider: Bool? = nil,
        definitionProvider: Bool? = nil,
        semanticTokensProvider: SemanticTokensOptions? = nil
    ) {
        self.textDocumentSync = textDocumentSync
        self.completionProvider = completionProvider
        self.hoverProvider = hoverProvider
        self.definitionProvider = definitionProvider
        self.semanticTokensProvider = semanticTokensProvider
    }
}

/// Text document sync options.
public struct TextDocumentSyncOptions: Codable, Sendable {
    /// Open and close notifications are sent
    public let openClose: Bool?
    /// Change notifications are sent (1 = full, 2 = incremental)
    public let change: Int?
    /// Save notifications are sent
    public let save: SaveOptions?

    public init(openClose: Bool? = true, change: Int? = 1, save: SaveOptions? = nil) {
        self.openClose = openClose
        self.change = change
        self.save = save
    }
}

/// Save options.
public struct SaveOptions: Codable, Sendable {
    /// Include the text content on save
    public let includeText: Bool?

    public init(includeText: Bool? = true) {
        self.includeText = includeText
    }
}

/// Completion provider options.
public struct CompletionOptions: Codable, Sendable {
    /// Trigger characters for completion
    public let triggerCharacters: [String]?
    /// The server provides support to resolve additional information
    public let resolveProvider: Bool?

    public init(triggerCharacters: [String]? = nil, resolveProvider: Bool? = nil) {
        self.triggerCharacters = triggerCharacters
        self.resolveProvider = resolveProvider
    }
}

/// Semantic tokens provider options.
public struct SemanticTokensOptions: Codable, Sendable {
    /// The legend used by the server
    public let legend: SemanticTokensLegend
    /// Server supports providing semantic tokens for a full document
    public let full: Bool?
    /// Server supports providing semantic tokens for a document range
    public let range: Bool?

    public init(legend: SemanticTokensLegend, full: Bool? = true, range: Bool? = nil) {
        self.legend = legend
        self.full = full
        self.range = range
    }
}

// MARK: - Initialize

/// Initialize request parameters.
public struct InitializeParams: Codable, Sendable {
    /// The process ID of the parent process
    public let processId: Int?
    /// The rootUri of the workspace
    public let rootUri: String?
    /// The capabilities provided by the client
    public let capabilities: ClientCapabilities

    public init(processId: Int?, rootUri: String?, capabilities: ClientCapabilities) {
        self.processId = processId
        self.rootUri = rootUri
        self.capabilities = capabilities
    }
}

/// Client capabilities (simplified).
public struct ClientCapabilities: Codable, Sendable {
    public init() {}
}

/// Initialize response result.
public struct InitializeResult: Codable, Sendable {
    /// The capabilities the language server provides
    public let capabilities: ServerCapabilities

    public init(capabilities: ServerCapabilities) {
        self.capabilities = capabilities
    }
}
