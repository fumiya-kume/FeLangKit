import Foundation
import FeLangCore

// MARK: - Completion Provider

/// Provides code completion for FE documents.
public struct CompletionProvider: Sendable {
    /// FE language keywords
    private static let keywords: [CompletionItem] = [
        // Control flow
        CompletionItem(label: "if", kind: .keyword, detail: "Conditional statement", insertText: "if "),
        CompletionItem(label: "then", kind: .keyword, detail: "Then clause"),
        CompletionItem(label: "else", kind: .keyword, detail: "Else clause"),
        CompletionItem(label: "elseif", kind: .keyword, detail: "Else-if clause", insertText: "elseif "),
        CompletionItem(label: "endif", kind: .keyword, detail: "End if statement"),

        // Loops
        CompletionItem(label: "while", kind: .keyword, detail: "While loop", insertText: "while "),
        CompletionItem(label: "do", kind: .keyword, detail: "Do clause"),
        CompletionItem(label: "endwhile", kind: .keyword, detail: "End while loop"),
        CompletionItem(label: "for", kind: .keyword, detail: "For loop", insertText: "for "),
        CompletionItem(label: "to", kind: .keyword, detail: "Range end"),
        CompletionItem(label: "step", kind: .keyword, detail: "Loop step"),
        CompletionItem(label: "endfor", kind: .keyword, detail: "End for loop"),
        CompletionItem(label: "in", kind: .keyword, detail: "For-each iteration"),

        // Control statements
        CompletionItem(label: "break", kind: .keyword, detail: "Exit loop"),
        CompletionItem(label: "continue", kind: .keyword, detail: "Continue to next iteration"),
        CompletionItem(label: "return", kind: .keyword, detail: "Return from function", insertText: "return "),

        // Functions and procedures
        CompletionItem(label: "function", kind: .keyword, detail: "Function declaration", insertText: "function "),
        CompletionItem(label: "endfunction", kind: .keyword, detail: "End function"),
        CompletionItem(label: "procedure", kind: .keyword, detail: "Procedure declaration", insertText: "procedure "),
        CompletionItem(label: "endprocedure", kind: .keyword, detail: "End procedure"),

        // Logical operators
        CompletionItem(label: "and", kind: .keyword, detail: "Logical AND"),
        CompletionItem(label: "or", kind: .keyword, detail: "Logical OR"),
        CompletionItem(label: "not", kind: .keyword, detail: "Logical NOT"),

        // Boolean literals
        CompletionItem(label: "true", kind: .keyword, detail: "Boolean true"),
        CompletionItem(label: "false", kind: .keyword, detail: "Boolean false"),

        // Japanese keywords
        CompletionItem(label: "もし", kind: .keyword, detail: "条件分岐 (if)", insertText: "もし "),
        CompletionItem(label: "ならば", kind: .keyword, detail: "Then clause"),
        CompletionItem(label: "でなければ", kind: .keyword, detail: "Else clause"),
        CompletionItem(label: "を実行", kind: .keyword, detail: "End if statement"),
        CompletionItem(label: "繰り返し", kind: .keyword, detail: "ループ (while)", insertText: "繰り返し "),
        CompletionItem(label: "を繰り返す", kind: .keyword, detail: "End while loop")
    ]

    /// FE data types
    private static let types: [CompletionItem] = [
        CompletionItem(label: "integer", kind: .typeParameter, detail: "Integer type (整数型)"),
        CompletionItem(label: "real", kind: .typeParameter, detail: "Real number type (実数型)"),
        CompletionItem(label: "string", kind: .typeParameter, detail: "String type (文字列型)"),
        CompletionItem(label: "character", kind: .typeParameter, detail: "Character type (文字型)"),
        CompletionItem(label: "boolean", kind: .typeParameter, detail: "Boolean type (論理型)"),
        CompletionItem(label: "array", kind: .typeParameter, detail: "Array type (配列型)"),

        // Japanese type names
        CompletionItem(label: "整数型", kind: .typeParameter, detail: "Integer type"),
        CompletionItem(label: "実数型", kind: .typeParameter, detail: "Real number type"),
        CompletionItem(label: "文字列型", kind: .typeParameter, detail: "String type"),
        CompletionItem(label: "文字型", kind: .typeParameter, detail: "Character type"),
        CompletionItem(label: "論理型", kind: .typeParameter, detail: "Boolean type"),
        CompletionItem(label: "配列型", kind: .typeParameter, detail: "Array type")
    ]

    /// Standard library functions
    private static let standardFunctions: [CompletionItem] = [
        // I/O
        CompletionItem(label: "print", kind: .function, detail: "Print to output", insertText: "print("),
        CompletionItem(label: "input", kind: .function, detail: "Read from input", insertText: "input()"),

        // Type conversion
        CompletionItem(label: "toInteger", kind: .function, detail: "Convert to integer", insertText: "toInteger("),
        CompletionItem(label: "toReal", kind: .function, detail: "Convert to real", insertText: "toReal("),
        CompletionItem(label: "toString", kind: .function, detail: "Convert to string", insertText: "toString("),

        // Math functions
        CompletionItem(label: "abs", kind: .function, detail: "Absolute value", insertText: "abs("),
        CompletionItem(label: "sqrt", kind: .function, detail: "Square root", insertText: "sqrt("),
        CompletionItem(label: "floor", kind: .function, detail: "Floor function", insertText: "floor("),
        CompletionItem(label: "ceil", kind: .function, detail: "Ceiling function", insertText: "ceil("),
        CompletionItem(label: "round", kind: .function, detail: "Round to nearest integer", insertText: "round("),
        CompletionItem(label: "min", kind: .function, detail: "Minimum of two values", insertText: "min("),
        CompletionItem(label: "max", kind: .function, detail: "Maximum of two values", insertText: "max("),
        CompletionItem(label: "pow", kind: .function, detail: "Power function", insertText: "pow("),

        // String functions
        CompletionItem(label: "length", kind: .function, detail: "String/array length", insertText: "length("),
        CompletionItem(label: "substring", kind: .function, detail: "Extract substring", insertText: "substring("),
        CompletionItem(label: "concat", kind: .function, detail: "Concatenate strings", insertText: "concat("),
        CompletionItem(label: "charAt", kind: .function, detail: "Character at index", insertText: "charAt("),
        CompletionItem(label: "indexOf", kind: .function, detail: "Find substring index", insertText: "indexOf("),

        // Array functions
        CompletionItem(label: "push", kind: .function, detail: "Add to array end", insertText: "push("),
        CompletionItem(label: "pop", kind: .function, detail: "Remove from array end", insertText: "pop(")
    ]

    public init() {}

    /// Provide completions at a position in a document.
    public func complete(document: inout Document, position: Position) -> CompletionList {
        var items: [CompletionItem] = []

        // Get context at position
        let context = getCompletionContext(document: &document, position: position)

        switch context {
        case .keyword:
            items.append(contentsOf: Self.keywords)
        case .type:
            items.append(contentsOf: Self.types)
        case .function:
            items.append(contentsOf: Self.standardFunctions)
            items.append(contentsOf: getUserDefinedFunctions(document: document))
        case .variable:
            items.append(contentsOf: getVariables(document: document))
            items.append(contentsOf: Self.standardFunctions)
        case .general:
            items.append(contentsOf: Self.keywords)
            items.append(contentsOf: Self.types)
            items.append(contentsOf: Self.standardFunctions)
            items.append(contentsOf: getVariables(document: document))
            items.append(contentsOf: getUserDefinedFunctions(document: document))
        }

        // Filter by prefix if there's a partial word
        if let (word, _) = document.wordAt(line: position.line, character: position.character) {
            let prefix = word.lowercased()
            items = items.filter { $0.label.lowercased().hasPrefix(prefix) }
        }

        return CompletionList(isIncomplete: false, items: items)
    }

    // MARK: - Context Detection

    private enum CompletionContext {
        case keyword
        case type
        case function
        case variable
        case general
    }

    private func getCompletionContext(document: inout Document, position: Position) -> CompletionContext {
        let lines = document.lines
        guard position.line >= 0, position.line < lines.count else {
            return .general
        }

        let line = String(lines[position.line])
        // Convert UTF-16 offset (LSP standard) to Swift String.Index
        let prefix: String
        if let utf16Index = line.utf16.index(line.utf16.startIndex, offsetBy: position.character, limitedBy: line.utf16.endIndex),
           let stringIndex = utf16Index.samePosition(in: line) {
            prefix = String(line[..<stringIndex])
        } else {
            prefix = line
        }

        // Check for type context (after colon)
        if prefix.contains(":") && !prefix.contains("←") {
            return .type
        }

        // Check for function call context (after opening paren or comma)
        if let lastChar = prefix.last, lastChar == "(" || lastChar == "," {
            return .variable
        }

        // Check for assignment context
        if prefix.contains("←") {
            return .variable
        }

        // Check for statement start
        let trimmed = prefix.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return .keyword
        }

        return .general
    }

    // MARK: - User Defined Items

    private func getVariables(document: Document) -> [CompletionItem] {
        var variables: [CompletionItem] = []
        var seen = Set<String>()

        // Simple regex-like pattern matching for variable declarations
        let patterns = [
            "\\b(\\w+)\\s*:", // variable: type
            "\\b(\\w+)\\s*←" // variable ← value
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(document.content.startIndex..., in: document.content)
                let matches = regex.matches(in: document.content, range: range)

                for match in matches {
                    if let varRange = Swift.Range(match.range(at: 1), in: document.content) {
                        let varName = String(document.content[varRange])
                        if !seen.contains(varName) && !isKeyword(varName) {
                            seen.insert(varName)
                            variables.append(CompletionItem(
                                label: varName,
                                kind: .variable,
                                detail: "Variable"
                            ))
                        }
                    }
                }
            }
        }

        return variables
    }

    private func getUserDefinedFunctions(document: Document) -> [CompletionItem] {
        var functions: [CompletionItem] = []
        var seen = Set<String>()

        // Pattern for function/procedure declarations
        let patterns = [
            "\\bfunction\\s+(\\w+)",
            "\\bprocedure\\s+(\\w+)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(document.content.startIndex..., in: document.content)
                let matches = regex.matches(in: document.content, range: range)

                for match in matches {
                    if let funcRange = Swift.Range(match.range(at: 1), in: document.content) {
                        let funcName = String(document.content[funcRange])
                        if !seen.contains(funcName) {
                            seen.insert(funcName)
                            functions.append(CompletionItem(
                                label: funcName,
                                kind: .function,
                                detail: "User-defined function",
                                insertText: "\(funcName)("
                            ))
                        }
                    }
                }
            }
        }

        return functions
    }

    private func isKeyword(_ word: String) -> Bool {
        let keywords = Set([
            // English keywords
            "if", "then", "else", "elseif", "endif",
            "while", "do", "endwhile",
            "for", "to", "step", "endfor", "in",
            "function", "endfunction", "procedure", "endprocedure",
            "return", "break", "continue",
            "and", "or", "not", "true", "false",
            "integer", "real", "string", "character", "boolean", "array",
            // Japanese keywords
            "もし", "ならば", "でなければ", "を実行", "繰り返し", "を繰り返す",
            // Japanese type names
            "整数型", "実数型", "文字列型", "文字型", "論理型", "配列型"
        ])
        return keywords.contains(word.lowercased()) || keywords.contains(word)
    }
}

// MARK: - Completion Request Params

/// Parameters for textDocument/completion request.
public struct CompletionParams: Codable, Sendable {
    /// The text document
    public let textDocument: TextDocumentIdentifier
    /// The position inside the text document
    public let position: Position

    public init(textDocument: TextDocumentIdentifier, position: Position) {
        self.textDocument = textDocument
        self.position = position
    }
}
