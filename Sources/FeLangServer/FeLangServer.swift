// FeLangServer - Language Server Protocol implementation for FE pseudo-language
//
// This module provides LSP support for FE programs, including:
// - LSPTypes: LSP protocol types (Position, Range, Diagnostic, etc.)
// - JSONRPCTransport: JSON-RPC communication layer
// - DocumentStore: Open document management
// - DiagnosticsProvider: Syntax and semantic error reporting
// - CompletionProvider: Code completion
// - HoverProvider: Hover information
// - DefinitionProvider: Go to definition
// - LanguageServer: Main server implementation

@_exported import FeLangCore
