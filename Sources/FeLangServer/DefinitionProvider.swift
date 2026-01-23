import Foundation
import FeLangCore

// MARK: - Definition Provider

/// Provides go-to-definition for FE documents.
public struct DefinitionProvider: Sendable {
    public init() {}

    /// Convert String.Index to UTF-16 offset for LSP compliance
    private func utf16Distance(in string: String, from start: String.Index, to end: String.Index) -> Int {
        return string.utf16.distance(from: start, to: end)
    }

    /// Find the definition of a symbol at a position.
    public func findDefinition(document: inout Document, position: Position) -> Location? {
        guard let (word, _) = document.wordAt(line: position.line, character: position.character) else {
            return nil
        }

        // Skip keywords and built-in functions
        if isBuiltIn(word) {
            return nil
        }

        // Look for the definition
        if let definitionRange = findDefinitionRange(word: word, document: &document) {
            return Location(uri: document.uri, range: definitionRange)
        }

        return nil
    }

    // MARK: - Definition Search

    private func findDefinitionRange(word: String, document: inout Document) -> Range? {
        let lines = document.lines

        for (lineNum, line) in lines.enumerated() {
            let lineStr = String(line)

            // Check for variable declaration: word: type or word ← value
            if let varRange = findVariableDeclaration(word: word, in: lineStr, lineNumber: lineNum) {
                return varRange
            }

            // Check for function declaration
            if let funcRange = findFunctionDeclaration(word: word, in: lineStr, lineNumber: lineNum) {
                return funcRange
            }

            // Check for procedure declaration
            if let procRange = findProcedureDeclaration(word: word, in: lineStr, lineNumber: lineNum) {
                return procRange
            }

            // Check for parameter in function/procedure signature
            if let paramRange = findParameterDeclaration(word: word, in: lineStr, lineNumber: lineNum) {
                return paramRange
            }
        }

        return nil
    }

    private func findVariableDeclaration(word: String, in line: String, lineNumber: Int) -> Range? {
        // Pattern: word: type or word ← value (as first occurrence, indicating declaration)
        let patterns = [
            "\\b(\(NSRegularExpression.escapedPattern(for: word)))\\s*:\\s*\\w+",
            "^\\s*(\(NSRegularExpression.escapedPattern(for: word)))\\s*←"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let wordRange = Swift.Range(match.range(at: 1), in: line) {
                let startChar = utf16Distance(in: line, from: line.startIndex, to: wordRange.lowerBound)
                let endChar = utf16Distance(in: line, from: line.startIndex, to: wordRange.upperBound)
                return Range(
                    startLine: lineNumber,
                    startCharacter: startChar,
                    endLine: lineNumber,
                    endCharacter: endChar
                )
            }
        }

        return nil
    }

    private func findFunctionDeclaration(word: String, in line: String, lineNumber: Int) -> Range? {
        let pattern = "\\bfunction\\s+(\(NSRegularExpression.escapedPattern(for: word)))\\s*\\("

        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let wordRange = Swift.Range(match.range(at: 1), in: line) {
            let startChar = utf16Distance(in: line, from: line.startIndex, to: wordRange.lowerBound)
            let endChar = utf16Distance(in: line, from: line.startIndex, to: wordRange.upperBound)
            return Range(
                startLine: lineNumber,
                startCharacter: startChar,
                endLine: lineNumber,
                endCharacter: endChar
            )
        }

        return nil
    }

    private func findProcedureDeclaration(word: String, in line: String, lineNumber: Int) -> Range? {
        let pattern = "\\bprocedure\\s+(\(NSRegularExpression.escapedPattern(for: word)))\\s*\\("

        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let wordRange = Swift.Range(match.range(at: 1), in: line) {
            let startChar = utf16Distance(in: line, from: line.startIndex, to: wordRange.lowerBound)
            let endChar = utf16Distance(in: line, from: line.startIndex, to: wordRange.upperBound)
            return Range(
                startLine: lineNumber,
                startCharacter: startChar,
                endLine: lineNumber,
                endCharacter: endChar
            )
        }

        return nil
    }

    private func findParameterDeclaration(word: String, in line: String, lineNumber: Int) -> Range? {
        // Check if line contains function/procedure and the word as a parameter
        let funcPattern = "(function|procedure)\\s+\\w+\\s*\\([^)]*\\b(\(NSRegularExpression.escapedPattern(for: word)))\\s*:"

        if let regex = try? NSRegularExpression(pattern: funcPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let wordRange = Swift.Range(match.range(at: 2), in: line) {
            let startChar = utf16Distance(in: line, from: line.startIndex, to: wordRange.lowerBound)
            let endChar = utf16Distance(in: line, from: line.startIndex, to: wordRange.upperBound)
            return Range(
                startLine: lineNumber,
                startCharacter: startChar,
                endLine: lineNumber,
                endCharacter: endChar
            )
        }

        return nil
    }

    // MARK: - Built-in Check

    private func isBuiltIn(_ word: String) -> Bool {
        let lowerWord = word.lowercased()

        // Keywords
        let keywords = Set([
            "if", "then", "else", "elif", "endif",
            "while", "do", "endwhile",
            "for", "to", "step", "endfor", "in",
            "function", "endfunction", "procedure", "endprocedure",
            "return", "break", "continue",
            "and", "or", "not", "true", "false"
        ])

        // Types
        let types = Set([
            "integer", "real", "string", "character", "boolean", "array",
            "整数型", "実数型", "文字列型", "文字型", "論理型", "配列型"
        ])

        // Standard library (matching StandardLibrary.swift)
        let stdlib = Set([
            "print", "println", "input",
            "tointeger", "toreal", "tostring",
            "abs", "sqrt", "floor", "ceil", "round", "min", "max", "pow",
            "length", "substring", "concat", "charat", "upper", "lower", "trim",
            "arraylength", "append", "prepend", "concat_arrays"
        ])

        return keywords.contains(lowerWord) || types.contains(word) || stdlib.contains(lowerWord)
    }
}

// MARK: - Definition Request Params

/// Parameters for textDocument/definition request.
public struct DefinitionParams: Codable, Sendable {
    /// The text document
    public let textDocument: TextDocumentIdentifier
    /// The position
    public let position: Position

    public init(textDocument: TextDocumentIdentifier, position: Position) {
        self.textDocument = textDocument
        self.position = position
    }
}
