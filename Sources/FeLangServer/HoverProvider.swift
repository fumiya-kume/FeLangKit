import Foundation
import FeLangCore

// MARK: - Hover Provider

/// Provides hover information for FE documents.
public struct HoverProvider: Sendable {
    /// Keyword documentation
    private static let keywordDocs: [String: String] = [
        // Control flow
        "if": "**if** - Conditional statement\n\nExecutes code based on a condition.\n\n```fe\nif condition then\n    // code\nendif\n```",
        "then": "**then** - Then clause\n\nMarks the beginning of the true branch in an if statement.",
        "else": "**else** - Else clause\n\nMarks the false branch in an if statement.",
        "elif": "**elif** - Else-if clause\n\nAdditional condition check in an if statement.",
        "endif": "**endif** - End if\n\nMarks the end of an if statement.",

        // Loops
        "while": "**while** - While loop\n\nRepeats code while a condition is true.\n\n```fe\nwhile condition do\n    // code\nendwhile\n```",
        "do": "**do** - Do clause\n\nMarks the beginning of a loop body.",
        "endwhile": "**endwhile** - End while\n\nMarks the end of a while loop.",
        "for": "**for** - For loop\n\nIterates over a range or collection.\n\n```fe\nfor i ← 1 to 10 do\n    // code\nendfor\n```",
        "to": "**to** - Range end\n\nSpecifies the end of a range in a for loop.",
        "step": "**step** - Loop step\n\nSpecifies the increment value in a for loop.",
        "endfor": "**endfor** - End for\n\nMarks the end of a for loop.",
        "in": "**in** - For-each iterator\n\nIterates over elements in a collection.\n\n```fe\nfor item in array do\n    // code\nendfor\n```",

        // Control statements
        "break": "**break** - Exit loop\n\nImmediately exits the current loop.",
        "continue": "**continue** - Continue\n\nSkips to the next iteration of the current loop.",
        "return": "**return** - Return\n\nReturns a value from a function.",

        // Functions
        "function": "**function** - Function declaration\n\nDeclares a function that returns a value.\n\n```fe\nfunction name(params): returnType\n    // code\n    return value\nendfunction\n```",
        "endfunction": "**endfunction** - End function\n\nMarks the end of a function declaration.",
        "procedure": "**procedure** - Procedure declaration\n\nDeclares a procedure (no return value).\n\n```fe\nprocedure name(params)\n    // code\nendprocedure\n```",
        "endprocedure": "**endprocedure** - End procedure\n\nMarks the end of a procedure declaration.",

        // Logical
        "and": "**and** - Logical AND\n\nReturns true if both operands are true.",
        "or": "**or** - Logical OR\n\nReturns true if either operand is true.",
        "not": "**not** - Logical NOT\n\nReturns the opposite of a boolean value.",

        // Literals
        "true": "**true** - Boolean true\n\nThe boolean value representing truth.",
        "false": "**false** - Boolean false\n\nThe boolean value representing falsehood.",

        // Japanese
        "もし": "**もし** (if) - 条件分岐\n\n条件に基づいてコードを実行します。",
        "ならば": "**ならば** (then) - Then節\n\nif文の真の分岐を開始します。",
        "でなければ": "**でなければ** (else) - Else節\n\nif文の偽の分岐です。",
        "を実行": "**を実行** (endif) - End if\n\nif文の終了を示します。",
        "繰り返し": "**繰り返し** (while) - ループ\n\n条件が真の間、コードを繰り返します。",
        "を繰り返す": "**を繰り返す** (endwhile) - ループ終了\n\nwhileループの終了を示します。"
    ]

    /// Type documentation
    private static let typeDocs: [String: String] = [
        "integer": "**integer** (整数型)\n\nWhole number type.\n\nRange: Platform dependent (typically 64-bit)",
        "real": "**real** (実数型)\n\nFloating-point number type.\n\nDouble precision (64-bit)",
        "string": "**string** (文字列型)\n\nText string type.\n\nUnicode support",
        "character": "**character** (文字型)\n\nSingle character type.\n\nUnicode character",
        "boolean": "**boolean** (論理型)\n\nBoolean type.\n\nValues: true, false",
        "array": "**array** (配列型)\n\nArray/list type.\n\nZero-indexed collection",
        "整数型": "**整数型** (integer)\n\n整数を表す型です。",
        "実数型": "**実数型** (real)\n\n浮動小数点数を表す型です。",
        "文字列型": "**文字列型** (string)\n\n文字列を表す型です。",
        "文字型": "**文字型** (character)\n\n単一の文字を表す型です。",
        "論理型": "**論理型** (boolean)\n\n真偽値を表す型です。",
        "配列型": "**配列型** (array)\n\n配列を表す型です。"
    ]

    /// Standard library function documentation
    private static let functionDocs: [String: String] = [
        "print": "**print(value)**\n\nOutputs a value to the console.\n\n**Parameters:**\n- `value`: Any value to print\n\n**Example:**\n```fe\nprint(\"Hello, World!\")\n```",
        "input": "**input()**\n\nReads a line from standard input.\n\n**Returns:** String\n\n**Example:**\n```fe\nname ← input()\n```",
        "toInteger": "**toInteger(value)**\n\nConverts a value to an integer.\n\n**Parameters:**\n- `value`: Value to convert\n\n**Returns:** Integer",
        "toReal": "**toReal(value)**\n\nConverts a value to a real number.\n\n**Parameters:**\n- `value`: Value to convert\n\n**Returns:** Real",
        "toString": "**toString(value)**\n\nConverts a value to a string.\n\n**Parameters:**\n- `value`: Value to convert\n\n**Returns:** String",
        "abs": "**abs(n)**\n\nReturns the absolute value.\n\n**Parameters:**\n- `n`: Numeric value\n\n**Returns:** Absolute value",
        "sqrt": "**sqrt(n)**\n\nReturns the square root.\n\n**Parameters:**\n- `n`: Non-negative number\n\n**Returns:** Square root",
        "floor": "**floor(n)**\n\nRounds down to the nearest integer.\n\n**Parameters:**\n- `n`: Real number\n\n**Returns:** Integer",
        "ceil": "**ceil(n)**\n\nRounds up to the nearest integer.\n\n**Parameters:**\n- `n`: Real number\n\n**Returns:** Integer",
        "round": "**round(n)**\n\nRounds to the nearest integer.\n\n**Parameters:**\n- `n`: Real number\n\n**Returns:** Integer",
        "min": "**min(a, b)**\n\nReturns the smaller value.\n\n**Parameters:**\n- `a`, `b`: Numeric values\n\n**Returns:** Minimum value",
        "max": "**max(a, b)**\n\nReturns the larger value.\n\n**Parameters:**\n- `a`, `b`: Numeric values\n\n**Returns:** Maximum value",
        "pow": "**pow(base, exp)**\n\nReturns base raised to the power of exp.\n\n**Parameters:**\n- `base`: Base number\n- `exp`: Exponent\n\n**Returns:** Result",
        "length": "**length(value)**\n\nReturns the length of a string or array.\n\n**Parameters:**\n- `value`: String or array\n\n**Returns:** Integer length",
        "substring": "**substring(str, start, end?)**\n\nExtracts a portion of a string.\n\n**Parameters:**\n- `str`: Source string\n- `start`: Start index\n- `end`: End index (optional)\n\n**Returns:** Substring",
        "concat": "**concat(a, b)**\n\nConcatenates two strings.\n\n**Parameters:**\n- `a`, `b`: Strings to concatenate\n\n**Returns:** Combined string",
        "charAt": "**charAt(str, index)**\n\nReturns the character at an index.\n\n**Parameters:**\n- `str`: Source string\n- `index`: Position\n\n**Returns:** Character",
        "indexOf": "**indexOf(str, search)**\n\nFinds the first occurrence of a substring.\n\n**Parameters:**\n- `str`: Source string\n- `search`: String to find\n\n**Returns:** Index or -1",
        "push": "**push(array, value)**\n\nAdds an element to the end of an array.\n\n**Parameters:**\n- `array`: Target array\n- `value`: Value to add",
        "pop": "**pop(array)**\n\nRemoves and returns the last element.\n\n**Parameters:**\n- `array`: Target array\n\n**Returns:** Removed element"
    ]

    public init() {}

    /// Provide hover information at a position.
    public func hover(document: inout Document, position: Position) -> Hover? {
        guard let (word, range) = document.wordAt(line: position.line, character: position.character) else {
            return nil
        }

        let lowerWord = word.lowercased()

        // Check keywords
        if let doc = Self.keywordDocs[word] ?? Self.keywordDocs[lowerWord] {
            return Hover(contents: .markdown(doc), range: range)
        }

        // Check types
        if let doc = Self.typeDocs[word] ?? Self.typeDocs[lowerWord] {
            return Hover(contents: .markdown(doc), range: range)
        }

        // Check standard library functions
        if let doc = Self.functionDocs[word] ?? Self.functionDocs[lowerWord] {
            return Hover(contents: .markdown(doc), range: range)
        }

        // Check for user-defined symbols
        if let symbolInfo = findSymbolInfo(word: word, document: document) {
            return Hover(contents: .markdown(symbolInfo), range: range)
        }

        return nil
    }

    // MARK: - Symbol Lookup

    private func findSymbolInfo(word: String, document: Document) -> String? {
        // Look for variable declarations
        let varPattern = "\(word)\\s*:\\s*(\\w+)"
        if let regex = try? NSRegularExpression(pattern: varPattern),
           let match = regex.firstMatch(
               in: document.content,
               range: NSRange(document.content.startIndex..., in: document.content)
           ),
           let typeRange = Swift.Range(match.range(at: 1), in: document.content) {
            let typeName = String(document.content[typeRange])
            return "**\(word)**: \(typeName)\n\nUser-defined variable"
        }

        // Look for function declarations
        let funcPattern = "function\\s+\(word)\\s*\\(([^)]*)\\)\\s*:\\s*(\\w+)"
        if let regex = try? NSRegularExpression(pattern: funcPattern, options: .caseInsensitive),
           let match = regex.firstMatch(
               in: document.content,
               range: NSRange(document.content.startIndex..., in: document.content)
           ) {
            var params = ""
            var returnType = ""

            if let paramsRange = Swift.Range(match.range(at: 1), in: document.content) {
                params = String(document.content[paramsRange])
            }
            if let returnRange = Swift.Range(match.range(at: 2), in: document.content) {
                returnType = String(document.content[returnRange])
            }

            return "**function \(word)**(\(params)): \(returnType)\n\nUser-defined function"
        }

        // Look for procedure declarations
        let procPattern = "procedure\\s+\(word)\\s*\\(([^)]*)\\)"
        if let regex = try? NSRegularExpression(pattern: procPattern, options: .caseInsensitive),
           let match = regex.firstMatch(
               in: document.content,
               range: NSRange(document.content.startIndex..., in: document.content)
           ) {
            var params = ""
            if let paramsRange = Swift.Range(match.range(at: 1), in: document.content) {
                params = String(document.content[paramsRange])
            }
            return "**procedure \(word)**(\(params))\n\nUser-defined procedure"
        }

        return nil
    }
}

// MARK: - Hover Request Params

/// Parameters for textDocument/hover request.
public struct HoverParams: Codable, Sendable {
    /// The text document
    public let textDocument: TextDocumentIdentifier
    /// The position
    public let position: Position

    public init(textDocument: TextDocumentIdentifier, position: Position) {
        self.textDocument = textDocument
        self.position = position
    }
}
