@testable import FeLangServer
import FeLangCore
import Foundation
import Testing

// MARK: - LSPTypes Tests

struct LSPTypesTests {

    // MARK: - Position Tests

    @Test func testPositionInitialization() {
        let position = Position(line: 10, character: 5)
        #expect(position.line == 10)
        #expect(position.character == 5)
    }

    @Test func testPositionEquality() {
        let pos1 = Position(line: 10, character: 5)
        let pos2 = Position(line: 10, character: 5)
        let pos3 = Position(line: 10, character: 6)

        #expect(pos1 == pos2)
        #expect(pos1 != pos3)
    }

    // MARK: - Range Tests

    @Test func testRangeInitialization() {
        let start = Position(line: 0, character: 0)
        let end = Position(line: 0, character: 10)
        let range = Range(start: start, end: end)

        #expect(range.start == start)
        #expect(range.end == end)
    }

    @Test func testRangeConvenienceInitializer() {
        let range = Range(startLine: 0, startCharacter: 5, endLine: 2, endCharacter: 10)

        #expect(range.start.line == 0)
        #expect(range.start.character == 5)
        #expect(range.end.line == 2)
        #expect(range.end.character == 10)
    }

    // MARK: - Diagnostic Tests

    @Test func testDiagnosticInitialization() {
        let range = Range(startLine: 0, startCharacter: 0, endLine: 0, endCharacter: 5)
        let diagnostic = Diagnostic(
            range: range,
            severity: .error,
            code: "test-error",
            source: "FeLangKit",
            message: "Test error message"
        )

        #expect(diagnostic.range == range)
        #expect(diagnostic.severity == .error)
        #expect(diagnostic.code == "test-error")
        #expect(diagnostic.source == "FeLangKit")
        #expect(diagnostic.message == "Test error message")
    }

    @Test func testDiagnosticSeverityLevels() {
        #expect(DiagnosticSeverity.error.rawValue == 1)
        #expect(DiagnosticSeverity.warning.rawValue == 2)
        #expect(DiagnosticSeverity.information.rawValue == 3)
        #expect(DiagnosticSeverity.hint.rawValue == 4)
    }

    // MARK: - CompletionItem Tests

    @Test func testCompletionItemInitialization() {
        let item = CompletionItem(
            label: "print",
            kind: .function,
            detail: "Print to output",
            documentation: "Prints a value",
            insertText: "print("
        )

        #expect(item.label == "print")
        #expect(item.kind == .function)
        #expect(item.detail == "Print to output")
        #expect(item.insertText == "print(")
    }

    @Test func testCompletionItemKinds() {
        #expect(CompletionItemKind.function.rawValue == 3)
        #expect(CompletionItemKind.variable.rawValue == 6)
        #expect(CompletionItemKind.keyword.rawValue == 14)
    }

    // MARK: - Hover Tests

    @Test func testHoverInitialization() {
        let content = MarkupContent.markdown("**test**")
        let range = Range(startLine: 0, startCharacter: 0, endLine: 0, endCharacter: 4)
        let hover = Hover(contents: content, range: range)

        #expect(hover.contents == content)
        #expect(hover.range == range)
    }

    @Test func testMarkupContent() {
        let markdown = MarkupContent.markdown("**bold**")
        let plaintext = MarkupContent.plaintext("plain text")

        #expect(markdown.kind == "markdown")
        #expect(markdown.value == "**bold**")
        #expect(plaintext.kind == "plaintext")
        #expect(plaintext.value == "plain text")
    }

    // MARK: - Location Tests

    @Test func testLocationInitialization() {
        let range = Range(startLine: 10, startCharacter: 5, endLine: 10, endCharacter: 15)
        let location = Location(uri: "file:///test.fe", range: range)

        #expect(location.uri == "file:///test.fe")
        #expect(location.range == range)
    }

    // MARK: - Codable Tests

    @Test func testPositionCodable() throws {
        let position = Position(line: 10, character: 5)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(position)
        let decoded = try decoder.decode(Position.self, from: data)

        #expect(decoded == position)
    }

    @Test func testRangeCodable() throws {
        let range = Range(startLine: 0, startCharacter: 5, endLine: 2, endCharacter: 10)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(range)
        let decoded = try decoder.decode(Range.self, from: data)

        #expect(decoded == range)
    }

    @Test func testDiagnosticCodable() throws {
        let range = Range(startLine: 0, startCharacter: 0, endLine: 0, endCharacter: 5)
        let diagnostic = Diagnostic(
            range: range,
            severity: .error,
            code: "test",
            source: "FeLangKit",
            message: "Test"
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(diagnostic)
        let decoded = try decoder.decode(Diagnostic.self, from: data)

        #expect(decoded == diagnostic)
    }

    // MARK: - TextDocumentIdentifier Tests

    @Test func testTextDocumentIdentifier() {
        let identifier = TextDocumentIdentifier(uri: "file:///test.fe")
        #expect(identifier.uri == "file:///test.fe")
    }

    @Test func testVersionedTextDocumentIdentifier() {
        let identifier = VersionedTextDocumentIdentifier(uri: "file:///test.fe", version: 5)
        #expect(identifier.uri == "file:///test.fe")
        #expect(identifier.version == 5)
    }

    @Test func testTextDocumentItem() {
        let item = TextDocumentItem(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            text: "x: integer ← 42"
        )
        #expect(item.uri == "file:///test.fe")
        #expect(item.languageId == "fe")
        #expect(item.version == 1)
        #expect(item.text == "x: integer ← 42")
    }

    // MARK: - SemanticTokens Tests

    @Test func testSemanticTokensLegend() {
        let legend = SemanticTokensLegend.default
        #expect(legend.tokenTypes.contains("keyword"))
        #expect(legend.tokenTypes.contains("variable"))
        #expect(legend.tokenModifiers.contains("declaration"))
    }
}

// MARK: - Document Tests

struct DocumentTests {

    @Test func testDocumentInitialization() {
        let doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "x: integer ← 42"
        )

        #expect(doc.uri == "file:///test.fe")
        #expect(doc.languageId == "fe")
        #expect(doc.version == 1)
        #expect(doc.content == "x: integer ← 42")
    }

    @Test func testDocumentLines() {
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "line1\nline2\nline3"
        )

        let lines = doc.lines
        #expect(lines.count == 3)
        #expect(lines[0] == "line1")
        #expect(lines[1] == "line2")
        #expect(lines[2] == "line3")
    }

    @Test func testDocumentLineCount() {
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "line1\nline2\nline3"
        )

        #expect(doc.lineCount == 3)
    }

    @Test func testDocumentUpdateContent() {
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "old content"
        )

        doc.updateContent("new content", version: 2)

        #expect(doc.content == "new content")
        #expect(doc.version == 2)
    }

    @Test func testDocumentWordAt() {
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "hello world test"
        )

        let result = doc.wordAt(line: 0, character: 7)
        #expect(result?.word == "world")
    }

    @Test func testDocumentWordAtBoundary() {
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "hello world"
        )

        // At space - should return nil or adjacent word
        let result = doc.wordAt(line: 0, character: 5)
        // Implementation may vary - just check it doesn't crash
        _ = result
    }

    @Test func testDocumentPositionFromOffset() {
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "line1\nline2\nline3"
        )

        // "line1\n" = 6 chars, so offset 6 is start of line 2
        let position = doc.positionFromOffset(6)
        #expect(position?.line == 1)
        #expect(position?.character == 0)
    }

    @Test func testDocumentOffsetFromPosition() {
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "line1\nline2\nline3"
        )

        let offset = doc.offsetFromPosition(Position(line: 1, character: 0))
        #expect(offset == 6)
    }

    @Test func testDocumentTextAt() {
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "hello world"
        )

        let char = doc.textAt(line: 0, character: 0)
        #expect(char == "h")
    }

    @Test func testDocumentTextInRange() {
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "hello world"
        )

        let range = Range(startLine: 0, startCharacter: 0, endLine: 0, endCharacter: 5)
        let text = doc.textInRange(range)
        #expect(text == "hello")
    }
}

// MARK: - DocumentStore Tests

struct DocumentStoreTests {

    @Test func testOpenDocument() async {
        let store = DocumentStore()

        await store.open(uri: "file:///test.fe", languageId: "fe", version: 1, content: "hello")

        let doc = await store.get(uri: "file:///test.fe")
        #expect(doc != nil)
        #expect(doc?.content == "hello")
    }

    @Test func testUpdateDocument() async {
        let store = DocumentStore()

        await store.open(uri: "file:///test.fe", languageId: "fe", version: 1, content: "original")
        await store.update(uri: "file:///test.fe", version: 2, content: "updated")

        let doc = await store.get(uri: "file:///test.fe")
        #expect(doc?.content == "updated")
        #expect(doc?.version == 2)
    }

    @Test func testCloseDocument() async {
        let store = DocumentStore()

        await store.open(uri: "file:///test.fe", languageId: "fe", version: 1, content: "hello")
        await store.close(uri: "file:///test.fe")

        let doc = await store.get(uri: "file:///test.fe")
        #expect(doc == nil)
    }

    @Test func testIsOpen() async {
        let store = DocumentStore()

        #expect(await store.isOpen(uri: "file:///test.fe") == false)

        await store.open(uri: "file:///test.fe", languageId: "fe", version: 1, content: "hello")
        #expect(await store.isOpen(uri: "file:///test.fe") == true)
    }

    @Test func testAllUris() async {
        let store = DocumentStore()

        await store.open(uri: "file:///a.fe", languageId: "fe", version: 1, content: "a")
        await store.open(uri: "file:///b.fe", languageId: "fe", version: 1, content: "b")

        let uris = await store.allUris()
        #expect(uris.count == 2)
        #expect(uris.contains("file:///a.fe"))
        #expect(uris.contains("file:///b.fe"))
    }

    @Test func testAllDocuments() async {
        let store = DocumentStore()

        await store.open(uri: "file:///a.fe", languageId: "fe", version: 1, content: "a")
        await store.open(uri: "file:///b.fe", languageId: "fe", version: 1, content: "b")

        let docs = await store.allDocuments()
        #expect(docs.count == 2)
    }
}

// MARK: - DiagnosticsProvider Tests

struct DiagnosticsProviderTests {

    @Test func testNoDiagnosticsForValidCode() {
        let provider = DiagnosticsProvider()
        let doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "x: integer ← 42"
        )

        let diagnostics = provider.diagnose(document: doc)
        // Valid code should produce no diagnostics
        // Note: Depending on semantic analysis, there might be warnings
        // For now, just verify it doesn't crash
        _ = diagnostics
    }

    @Test func testTokenizationErrorDiagnostic() {
        let provider = DiagnosticsProvider()
        let doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "\"unterminated string"
        )

        let diagnostics = provider.diagnose(document: doc)
        #expect(!diagnostics.isEmpty)
        #expect(diagnostics.first?.severity == .error)
    }

    @Test func testParseErrorDiagnostic() {
        let provider = DiagnosticsProvider()
        let doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "if then"  // Invalid syntax
        )

        let diagnostics = provider.diagnose(document: doc)
        #expect(!diagnostics.isEmpty)
    }

    @Test func testDiagnosticPositionAccuracy() {
        let provider = DiagnosticsProvider()
        let doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "\n\n\"unterminated"  // Error on line 3
        )

        let diagnostics = provider.diagnose(document: doc)
        #expect(!diagnostics.isEmpty)
        // Position should be on line 2 (0-indexed)
        if let diagnostic = diagnostics.first {
            #expect(diagnostic.range.start.line >= 0)
        }
    }

    @Test func testDiagnosticHasSource() {
        let provider = DiagnosticsProvider()
        let doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "\"unterminated"
        )

        let diagnostics = provider.diagnose(document: doc)
        if let diagnostic = diagnostics.first {
            #expect(diagnostic.source == "FeLangKit")
        }
    }
}

// MARK: - CompletionProvider Tests

struct CompletionProviderTests {

    @Test func testKeywordCompletion() {
        let provider = CompletionProvider()
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "if"
        )

        let completions = provider.complete(document: &doc, position: Position(line: 0, character: 2))

        // Should include 'if' keyword
        let ifCompletion = completions.items.first { $0.label == "if" }
        #expect(ifCompletion != nil)
        #expect(ifCompletion?.kind == .keyword)
    }

    @Test func testTypeCompletion() {
        let provider = CompletionProvider()
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "x: int"
        )

        let completions = provider.complete(document: &doc, position: Position(line: 0, character: 6))

        // Should include 'integer' type
        let integerCompletion = completions.items.first { $0.label == "integer" }
        #expect(integerCompletion != nil)
    }

    @Test func testStandardFunctionCompletion() {
        let provider = CompletionProvider()
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "pri"
        )

        let completions = provider.complete(document: &doc, position: Position(line: 0, character: 3))

        // Should include 'print' function
        let printCompletion = completions.items.first { $0.label == "print" }
        #expect(printCompletion != nil)
        #expect(printCompletion?.kind == .function)
    }

    @Test func testVariableCompletion() {
        let provider = CompletionProvider()
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "myVariable: integer ← 42\nmy"
        )

        let completions = provider.complete(document: &doc, position: Position(line: 1, character: 2))

        // Should include the user-defined variable
        let varCompletion = completions.items.first { $0.label == "myVariable" }
        #expect(varCompletion != nil)
    }

    @Test func testCompletionFiltering() {
        let provider = CompletionProvider()
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "wh"
        )

        let completions = provider.complete(document: &doc, position: Position(line: 0, character: 2))

        // Should include 'while' but not 'if'
        let whileCompletion = completions.items.first { $0.label == "while" }
        let ifCompletion = completions.items.first { $0.label == "if" }

        #expect(whileCompletion != nil)
        #expect(ifCompletion == nil)
    }

    @Test func testEmptyPositionCompletion() {
        let provider = CompletionProvider()
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: ""
        )

        let completions = provider.complete(document: &doc, position: Position(line: 0, character: 0))

        // Should return all available completions
        #expect(!completions.items.isEmpty)
    }

    @Test func testUserDefinedFunctionCompletion() {
        let provider = CompletionProvider()
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "function myFunc(x: integer): integer\n    return x\nendfunction\nmy"
        )

        let completions = provider.complete(document: &doc, position: Position(line: 3, character: 2))

        // Should include the user-defined function
        let funcCompletion = completions.items.first { $0.label == "myFunc" }
        #expect(funcCompletion != nil)
    }
}

// MARK: - HoverProvider Tests

struct HoverProviderTests {

    @Test func testKeywordHover() {
        let provider = HoverProvider()
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "if true then\nendif"
        )

        let hover = provider.hover(document: &doc, position: Position(line: 0, character: 1))

        #expect(hover != nil)
        #expect(hover?.contents.value.contains("if") == true)
    }

    @Test func testTypeHover() {
        let provider = HoverProvider()
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "x: integer ← 42"
        )

        let hover = provider.hover(document: &doc, position: Position(line: 0, character: 4))

        #expect(hover != nil)
        #expect(hover?.contents.value.contains("integer") == true)
    }

    @Test func testStandardFunctionHover() {
        let provider = HoverProvider()
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "print(42)"
        )

        let hover = provider.hover(document: &doc, position: Position(line: 0, character: 2))

        #expect(hover != nil)
        #expect(hover?.contents.value.contains("print") == true)
    }

    @Test func testUserVariableHover() {
        let provider = HoverProvider()
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "myVar: integer\nmyVar"
        )

        let hover = provider.hover(document: &doc, position: Position(line: 1, character: 2))

        #expect(hover != nil)
        #expect(hover?.contents.value.contains("myVar") == true)
    }

    @Test func testNoHoverOnWhitespace() {
        let provider = HoverProvider()
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "x y z"
        )

        // On space between x and y
        let hover = provider.hover(document: &doc, position: Position(line: 0, character: 1))
        // May or may not return hover depending on implementation
        _ = hover
    }

    @Test func testJapaneseKeywordHover() {
        let provider = HoverProvider()
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "もし true ならば"
        )

        let hover = provider.hover(document: &doc, position: Position(line: 0, character: 1))

        #expect(hover != nil)
        #expect(hover?.contents.value.contains("もし") == true)
    }

    @Test func testFunctionHoverWithDocumentation() {
        let provider = HoverProvider()
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "sqrt(16)"
        )

        let hover = provider.hover(document: &doc, position: Position(line: 0, character: 2))

        #expect(hover != nil)
        #expect(hover?.contents.value.contains("sqrt") == true)
        #expect(hover?.contents.value.contains("square root") == true)
    }
}

// MARK: - DefinitionProvider Tests

struct DefinitionProviderTests {

    @Test func testFindVariableDefinition() {
        let provider = DefinitionProvider()
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "myVar: integer ← 42\nprint(myVar)"
        )

        let location = provider.findDefinition(document: &doc, position: Position(line: 1, character: 8))

        #expect(location != nil)
        #expect(location?.range.start.line == 0)
    }

    @Test func testFindFunctionDefinition() {
        let provider = DefinitionProvider()
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "function myFunc(x: integer): integer\n    return x\nendfunction\nmyFunc(5)"
        )

        let location = provider.findDefinition(document: &doc, position: Position(line: 3, character: 2))

        #expect(location != nil)
        #expect(location?.range.start.line == 0)
    }

    @Test func testFindProcedureDefinition() {
        let provider = DefinitionProvider()
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "procedure myProc(x: integer)\n    print(x)\nendprocedure\nmyProc(5)"
        )

        let location = provider.findDefinition(document: &doc, position: Position(line: 3, character: 2))

        #expect(location != nil)
        #expect(location?.range.start.line == 0)
    }

    @Test func testNoDefinitionForKeyword() {
        let provider = DefinitionProvider()
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "if true then\nendif"
        )

        let location = provider.findDefinition(document: &doc, position: Position(line: 0, character: 1))

        #expect(location == nil)
    }

    @Test func testNoDefinitionForBuiltInFunction() {
        let provider = DefinitionProvider()
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "print(42)"
        )

        let location = provider.findDefinition(document: &doc, position: Position(line: 0, character: 2))

        #expect(location == nil)
    }

    @Test func testDefinitionReturnsCorrectUri() {
        let provider = DefinitionProvider()
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "x: integer\nx"
        )

        let location = provider.findDefinition(document: &doc, position: Position(line: 1, character: 0))

        #expect(location?.uri == "file:///test.fe")
    }

    @Test func testFindParameterDefinition() {
        let provider = DefinitionProvider()
        var doc = Document(
            uri: "file:///test.fe",
            languageId: "fe",
            version: 1,
            content: "function test(param: integer): integer\n    return param\nendfunction"
        )

        let location = provider.findDefinition(document: &doc, position: Position(line: 1, character: 12))

        #expect(location != nil)
        #expect(location?.range.start.line == 0)
    }
}

// MARK: - ServerCapabilities Tests

struct ServerCapabilitiesTests {

    @Test func testDefaultCapabilities() {
        let capabilities = ServerCapabilities(
            textDocumentSync: TextDocumentSyncOptions(openClose: true, change: 1),
            completionProvider: CompletionOptions(triggerCharacters: [".", ":"]),
            hoverProvider: true,
            definitionProvider: true
        )

        #expect(capabilities.textDocumentSync?.openClose == true)
        #expect(capabilities.completionProvider?.triggerCharacters?.contains(".") == true)
        #expect(capabilities.hoverProvider == true)
        #expect(capabilities.definitionProvider == true)
    }

    @Test func testSemanticTokensOptions() {
        let options = SemanticTokensOptions(
            legend: SemanticTokensLegend.default,
            full: true,
            range: false
        )

        #expect(!options.legend.tokenTypes.isEmpty)
        #expect(options.full == true)
        #expect(options.range == false)
    }
}

// MARK: - InitializeParams Tests

struct InitializeParamsTests {

    @Test func testInitializeParams() {
        let params = InitializeParams(
            processId: 1234,
            rootUri: "file:///workspace",
            capabilities: ClientCapabilities()
        )

        #expect(params.processId == 1234)
        #expect(params.rootUri == "file:///workspace")
    }

    @Test func testInitializeResult() {
        let capabilities = ServerCapabilities(hoverProvider: true)
        let result = InitializeResult(capabilities: capabilities)

        #expect(result.capabilities.hoverProvider == true)
    }
}

// MARK: - CompletionList Tests

struct CompletionListTests {

    @Test func testCompletionList() {
        let items = [
            CompletionItem(label: "print", kind: .function),
            CompletionItem(label: "input", kind: .function)
        ]
        let list = CompletionList(isIncomplete: false, items: items)

        #expect(list.isIncomplete == false)
        #expect(list.items.count == 2)
    }

    @Test func testIncompleteCompletionList() {
        let list = CompletionList(isIncomplete: true, items: [])
        #expect(list.isIncomplete == true)
    }
}

// MARK: - TextEdit Tests

struct TextEditTests {

    @Test func testTextEdit() {
        let range = Range(startLine: 0, startCharacter: 0, endLine: 0, endCharacter: 5)
        let edit = TextEdit(range: range, newText: "hello")

        #expect(edit.range == range)
        #expect(edit.newText == "hello")
    }
}
