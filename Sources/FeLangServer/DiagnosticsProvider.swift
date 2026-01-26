import Foundation
import FeLangCore

// MARK: - Diagnostics Provider

/// Provides diagnostic information for FE documents.
public struct DiagnosticsProvider: Sendable {
    public init() {}

    /// Analyze a document and return diagnostics.
    public func diagnose(document: Document) -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []

        // Step 1: Tokenization diagnostics
        diagnostics.append(contentsOf: tokenizationDiagnostics(for: document.content))

        // Step 2: Parsing diagnostics
        if diagnostics.isEmpty {
            diagnostics.append(contentsOf: parsingDiagnostics(for: document.content))
        }

        // Step 3: Semantic diagnostics (only if parsing succeeded)
        if diagnostics.isEmpty {
            diagnostics.append(contentsOf: semanticDiagnostics(for: document.content))
        }

        return diagnostics
    }

    // MARK: - Tokenization Diagnostics

    private func tokenizationDiagnostics(for content: String) -> [Diagnostic] {
        do {
            _ = try ParsingTokenizer.tokenize(content)
            return []
        } catch let error as TokenizerError {
            return [tokenizerErrorToDiagnostic(error)]
        } catch {
            return [genericErrorDiagnostic(error.localizedDescription)]
        }
    }

    private func tokenizerErrorToDiagnostic(_ error: TokenizerError) -> Diagnostic {
        let position = extractPositionFromTokenizerError(error)
        let range = Range(start: position, end: position)

        return Diagnostic(
            range: range,
            severity: .error,
            code: "tokenizer-error",
            source: "FeLangKit",
            message: error.description
        )
    }

    private func extractPositionFromTokenizerError(_ error: TokenizerError) -> Position {
        let sourcePos: SourcePosition
        switch error {
        case .unexpectedCharacter(_, let pos):
            sourcePos = pos
        case .unterminatedString(let pos):
            sourcePos = pos
        case .unterminatedComment(let pos):
            sourcePos = pos
        case .invalidEscapeSequence(let pos):
            sourcePos = pos
        case .invalidEscapeSequenceWithMessage(_, let pos):
            sourcePos = pos
        case .invalidUnicodeEscape(_, let pos):
            sourcePos = pos
        case .invalidNumberFormat(_, let pos):
            sourcePos = pos
        case .invalidDigitForBase(_, _, let pos):
            sourcePos = pos
        case .invalidUnderscorePlacement(let pos):
            sourcePos = pos
        }
        return Position(line: max(0, sourcePos.line - 1), character: max(0, sourcePos.column - 1))
    }

    // MARK: - Parsing Diagnostics

    private func parsingDiagnostics(for content: String) -> [Diagnostic] {
        do {
            let parser = Parser()
            _ = try parser.parse(content)
            return []
        } catch let error as ParseError {
            return [parseErrorToDiagnostic(error)]
        } catch {
            return [genericErrorDiagnostic(error.localizedDescription)]
        }
    }

    private func parseErrorToDiagnostic(_ error: ParseError) -> Diagnostic {
        let line = max(0, error.line - 1)
        let column = max(0, error.column - 1)
        let position = Position(line: line, character: column)
        let range = Range(start: position, end: position)

        return Diagnostic(
            range: range,
            severity: .error,
            code: "parse-error",
            source: "FeLangKit",
            message: error.message
        )
    }

    // MARK: - Semantic Diagnostics

    private func semanticDiagnostics(for content: String) -> [Diagnostic] {
        do {
            let parser = Parser()
            let statements = try parser.parse(content)
            let analyzer = SemanticAnalyzer()
            let result = analyzer.analyze(statements)

            var diagnostics: [Diagnostic] = []

            // Convert errors
            for error in result.errors {
                diagnostics.append(semanticErrorToDiagnostic(error))
            }

            // Convert warnings
            for warning in result.warnings {
                diagnostics.append(semanticWarningToDiagnostic(warning))
            }

            return diagnostics
        } catch {
            // Parsing failed, but we already handled that
            return []
        }
    }

    private func semanticErrorToDiagnostic(_ error: SemanticError) -> Diagnostic {
        let (position, code) = extractInfoFromSemanticError(error)
        let range = Range(start: position, end: position)

        return Diagnostic(
            range: range,
            severity: .error,
            code: code,
            source: "FeLangKit",
            message: error.errorDescription ?? String(describing: error)
        )
    }

    private func semanticWarningToDiagnostic(_ warning: SemanticWarning) -> Diagnostic {
        let info = extractInfoFromSemanticWarning(warning)
        let range = Range(start: info.position, end: info.position)

        return Diagnostic(
            range: range,
            severity: info.severity,
            code: info.code,
            source: "FeLangKit",
            message: warning.description
        )
    }

    private func extractInfoFromSemanticError(_ error: SemanticError) -> (Position, String) {
        let position = extractPositionFromSemanticError(error)
        let code = extractCodeFromSemanticError(error)
        return (position, code)
    }

    private func extractPositionFromSemanticError(_ error: SemanticError) -> Position {
        let sourcePos: SourcePosition? = {
            switch error {
            case .typeMismatch(_, _, let pos),
                 .incompatibleTypes(_, _, _, let pos),
                 .unknownType(_, let pos),
                 .invalidTypeConversion(_, _, let pos),
                 .undeclaredVariable(_, let pos),
                 .variableAlreadyDeclared(_, let pos),
                 .variableNotInitialized(_, let pos),
                 .constantReassignment(_, let pos),
                 .invalidAssignmentTarget(let pos),
                 .undeclaredFunction(_, let pos),
                 .functionAlreadyDeclared(_, let pos),
                 .incorrectArgumentCount(_, _, _, let pos),
                 .argumentTypeMismatch(_, _, _, _, let pos),
                 .missingReturnStatement(_, let pos),
                 .returnTypeMismatch(_, _, _, let pos),
                 .voidFunctionReturnsValue(_, let pos),
                 .unreachableCode(let pos),
                 .breakOutsideLoop(let pos),
                 .continueOutsideLoop(let pos),
                 .returnOutsideFunction(let pos),
                 .globalDeclarationInsideFunction(let pos),
                 .invalidArrayAccess(let pos),
                 .arrayIndexTypeMismatch(_, _, let pos),
                 .invalidArrayDimension(let pos),
                 .undeclaredField(_, _, let pos),
                 .invalidFieldAccess(let pos),
                 .cyclicDependency(_, let pos),
                 .analysisDepthExceeded(let pos):
                return pos
            case .tooManyErrors:
                return nil
            }
        }()

        if let pos = sourcePos {
            return Position(line: max(0, pos.line - 1), character: max(0, pos.column - 1))
        }
        return Position(line: 0, character: 0)
    }

    private func extractCodeFromSemanticError(_ error: SemanticError) -> String {
        switch error {
        case .typeMismatch: return "type-mismatch"
        case .incompatibleTypes: return "incompatible-types"
        case .unknownType: return "unknown-type"
        case .invalidTypeConversion: return "invalid-type-conversion"
        case .undeclaredVariable: return "undeclared-variable"
        case .variableAlreadyDeclared: return "variable-already-declared"
        case .variableNotInitialized: return "variable-not-initialized"
        case .constantReassignment: return "constant-reassignment"
        case .invalidAssignmentTarget: return "invalid-assignment-target"
        case .undeclaredFunction: return "undeclared-function"
        case .functionAlreadyDeclared: return "function-already-declared"
        case .incorrectArgumentCount: return "incorrect-argument-count"
        case .argumentTypeMismatch: return "argument-type-mismatch"
        case .missingReturnStatement: return "missing-return"
        case .returnTypeMismatch: return "return-type-mismatch"
        case .voidFunctionReturnsValue: return "void-function-returns-value"
        case .unreachableCode: return "unreachable-code"
        case .breakOutsideLoop: return "break-outside-loop"
        case .continueOutsideLoop: return "continue-outside-loop"
        case .returnOutsideFunction: return "return-outside-function"
        case .globalDeclarationInsideFunction: return "global-declaration-inside-function"
        case .invalidArrayAccess: return "invalid-array-access"
        case .arrayIndexTypeMismatch: return "array-index-type-mismatch"
        case .invalidArrayDimension: return "invalid-array-dimension"
        case .undeclaredField: return "undeclared-field"
        case .invalidFieldAccess: return "invalid-field-access"
        case .cyclicDependency: return "cyclic-dependency"
        case .analysisDepthExceeded: return "analysis-depth-exceeded"
        case .tooManyErrors: return "too-many-errors"
        }
    }

    private struct WarningInfo {
        let position: Position
        let severity: DiagnosticSeverity
        let code: String
    }

    private func extractInfoFromSemanticWarning(_ warning: SemanticWarning) -> WarningInfo {
        let position: Position
        let severity: DiagnosticSeverity
        let code: String

        switch warning {
        case .unusedVariable(_, let pos):
            position = Position(line: max(0, pos.line - 1), character: max(0, pos.column - 1))
            severity = .warning
            code = "unused-variable"
        case .unusedFunction(_, let pos):
            position = Position(line: max(0, pos.line - 1), character: max(0, pos.column - 1))
            severity = .warning
            code = "unused-function"
        case .unreachableCode(let pos):
            position = Position(line: max(0, pos.line - 1), character: max(0, pos.column - 1))
            severity = .warning
            code = "unreachable-code"
        case .implicitTypeConversion(_, _, let pos):
            position = Position(line: max(0, pos.line - 1), character: max(0, pos.column - 1))
            severity = .information
            code = "implicit-type-conversion"
        case .shadowedVariable(_, let pos):
            position = Position(line: max(0, pos.line - 1), character: max(0, pos.column - 1))
            severity = .warning
            code = "shadowed-variable"
        case .inefficientOperation(_, let pos):
            position = Position(line: max(0, pos.line - 1), character: max(0, pos.column - 1))
            severity = .hint
            code = "inefficient-operation"
        }

        return WarningInfo(position: position, severity: severity, code: code)
    }

    // MARK: - Helper Methods

    private func genericErrorDiagnostic(_ message: String) -> Diagnostic {
        Diagnostic(
            range: Range(startLine: 0, startCharacter: 0, endLine: 0, endCharacter: 0),
            severity: .error,
            code: "internal-error",
            source: "FeLangKit",
            message: message
        )
    }
}

// MARK: - Publish Diagnostics Notification

/// Parameters for the textDocument/publishDiagnostics notification.
public struct PublishDiagnosticsParams: Codable, Sendable {
    /// The URI for which diagnostics are reported
    public let uri: String
    /// The diagnostics
    public let diagnostics: [Diagnostic]

    public init(uri: String, diagnostics: [Diagnostic]) {
        self.uri = uri
        self.diagnostics = diagnostics
    }
}
