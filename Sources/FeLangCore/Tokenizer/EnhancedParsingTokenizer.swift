import Foundation

/// Enhanced parsing tokenizer with error recovery and multi-error collection
public struct EnhancedParsingTokenizer {

    public init() {}

    /// Tokenize input with comprehensive error handling and recovery
    public func tokenizeWithDiagnostics(_ input: String) -> TokenizerResult {
        // Normalize input before tokenization
        let normalizedInput = UnicodeNormalizer.normalizeForFE(input)
        let errorCollector = ErrorCollector()
        var tokens: [Token] = []
        var index = normalizedInput.startIndex
        let startIndex = index

        while index < normalizedInput.endIndex {
            let position = TokenizerUtilities.sourcePosition(from: normalizedInput, startIndex: startIndex, currentIndex: index)

            // Skip whitespace and newlines
            if normalizedInput[index].isWhitespace {
                index = normalizedInput.index(after: index)
                continue
            }

            // Try to parse a token with error recovery
            let beforeIndex = index

            if let token = parseNextTokenWithRecovery(
                from: normalizedInput,
                at: &index,
                startIndex: startIndex,
                errorCollector: errorCollector
            ) {
                let tokenWithPosition = Token(
                    type: token.type,
                    lexeme: token.lexeme,
                    position: position
                )
                tokens.append(tokenWithPosition)
            } else {
                // No token parsed - handle as unexpected character
                if index < normalizedInput.endIndex {
                    let char = normalizedInput[index]
                    if let scalar = char.unicodeScalars.first {
                        // Check if it's a potentially problematic character
                        if shouldReportAsError(char) {
                            errorCollector.addError(
                                type: .unexpectedCharacter(scalar),
                                range: SourceRange(at: position),
                                message: "Unexpected character '\(char)'",
                                suggestions: getSuggestionsForCharacter(char),
                                severity: .error,
                                context: "Character '\(char)' is not valid in this context"
                            )
                        }
                    }
                    index = normalizedInput.index(after: index)
                }
            }

            // Safety check to prevent infinite loops
            if index == beforeIndex {
                // Force advance if we're stuck
                if index < normalizedInput.endIndex {
                    index = normalizedInput.index(after: index)
                }
            }

            // Check if we should stop due to fatal errors
            if errorCollector.hasFatalErrors {
                break
            }
        }

        // Add EOF token
        let finalPosition = TokenizerUtilities.sourcePosition(from: normalizedInput, startIndex: startIndex, currentIndex: index)
        tokens.append(Token(type: .eof, lexeme: "", position: finalPosition))

        return errorCollector.createResult(with: tokens)
    }

    /// Legacy method for backward compatibility (throws on first error)
    public func tokenize(_ input: String) throws -> [Token] {
        let result = tokenizeWithDiagnostics(input)

        // Throw first error if any exist
        if let firstError = result.errors.first {
                    // Convert back to legacy error for compatibility
        throw self.convertToLegacyError(firstError)
        }

        return result.tokens
    }

    // MARK: - Private Methods

    private func shouldReportAsError(_ char: Character) -> Bool {
        // Report error for common problematic characters
        let problematicChars: Set<Character> = ["@", "#", "$", "%", "&", "^", "~", "`"]
        return problematicChars.contains(char) || (!char.isASCII && !char.isWhitespace)
    }

    private func getSuggestionsForCharacter(_ char: Character) -> [String] {
        switch char {
        case "@":
            return ["Remove this character", "Use valid identifier characters (letters, numbers, underscore)"]
        case "#":
            return ["Remove this character", "Use // for comments"]
        case "$":
            return ["Remove this character", "Use valid identifier syntax"]
        case "%":
            return ["Remove this character", "Use valid operators"]
        default:
            return ["Remove this character", "Replace with a valid character", "Check character encoding"]
        }
    }

    private func parseNextTokenWithRecovery(
        from input: String,
        at index: inout String.Index,
        startIndex: String.Index,
        errorCollector: ErrorCollector
    ) -> TokenData? {

        // Try to parse comments first (skip them, don't return tokens)
        if let commentResult = parseCommentWithRecovery(from: input, at: &index, startIndex: startIndex, errorCollector: errorCollector) {
            return commentResult // nil if comment was skipped
        }

        // Try to parse keywords and identifiers together
        if let token = parseKeywordOrIdentifier(from: input, at: &index) {
            return token
        }

        // Try to parse operators
        if let token = parseOperator(from: input, at: &index) {
            return token
        }

        // Try to parse numbers with error recovery
        if let token = parseNumberWithRecovery(from: input, at: &index, startIndex: startIndex, errorCollector: errorCollector) {
            return token
        }

        // Try to parse delimiters
        if let token = parseDelimiter(from: input, at: &index) {
            return token
        }

        // Try to parse strings with error recovery
        if let token = parseStringWithRecovery(from: input, at: &index, startIndex: startIndex, errorCollector: errorCollector) {
            return token
        }

        return nil
    }

    private func parseCommentWithRecovery(
        from input: String,
        at index: inout String.Index,
        startIndex: String.Index,
        errorCollector: ErrorCollector
    ) -> TokenData? {
        guard index < input.endIndex && input[index] == "/" else { return nil }

        let nextIndex = input.index(after: index)
        guard nextIndex < input.endIndex else { return nil }

        let nextChar = input[nextIndex]
        let position = TokenizerUtilities.sourcePosition(from: input, startIndex: startIndex, currentIndex: index)

        if nextChar == "/" {
            // Single-line comment - always succeeds
            index = nextIndex
            index = input.index(after: index)

            while index < input.endIndex && input[index] != "\n" {
                index = input.index(after: index)
            }

            return nil // Comments are skipped
        } else if nextChar == "*" {
            // Multi-line comment with recovery
            index = nextIndex
            index = input.index(after: index)

            while index < input.endIndex {
                if input[index] == "*" {
                    let nextIndex = input.index(after: index)
                    if nextIndex < input.endIndex && input[nextIndex] == "/" {
                        index = input.index(after: nextIndex)
                        return nil // Successfully closed comment
                    }
                }
                index = input.index(after: index)
            }

            // Unterminated comment - report error but don't throw
            errorCollector.addError(
                type: .unterminatedComment,
                range: SourceRange(at: position),
                message: "Unterminated multi-line comment",
                suggestions: ["Add closing */", "Check for nested comments"],
                severity: .error,
                context: "Multi-line comments must be properly closed"
            )

            return nil // Comment was processed even though unterminated
        }

        return nil
    }

    private func parseStringWithRecovery(
        from input: String,
        at index: inout String.Index,
        startIndex: String.Index,
        errorCollector: ErrorCollector
    ) -> TokenData? {
        guard index < input.endIndex else { return nil }

        let quoteChar = input[index]
        guard quoteChar == "\"" || quoteChar == "'" else { return nil }

        let start = index
        let position = TokenizerUtilities.sourcePosition(from: input, startIndex: startIndex, currentIndex: index)
        index = input.index(after: index) // Skip opening quote

        var content = ""
        var foundClosing = false

        while index < input.endIndex {
            let char = input[index]

            if char == quoteChar {
                foundClosing = true
                index = input.index(after: index) // Skip closing quote
                break
            } else if char == "\n" {
                // Unterminated string at newline - stop here with error
                break
            } else if char == "\\" {
                // Handle escape sequences with recovery
                let nextIndex = input.index(after: index)
                if nextIndex < input.endIndex {
                    let nextChar = input[nextIndex]
                    switch nextChar {
                    case "n":
                        content.append("\n")
                        index = input.index(after: nextIndex)
                    case "t":
                        content.append("\t")
                        index = input.index(after: nextIndex)
                    case "r":
                        content.append("\r")
                        index = input.index(after: nextIndex)
                    case "\\":
                        content.append("\\")
                        index = input.index(after: nextIndex)
                    case "\"":
                        content.append("\"")
                        index = input.index(after: nextIndex)
                    case "'":
                        content.append("'")
                        index = input.index(after: nextIndex)
                    default:
                        // Invalid escape sequence - report error but continue
                        errorCollector.addError(
                            type: .invalidEscapeSequence("\\(nextChar)"),
                            range: SourceRange(at: TokenizerUtilities.sourcePosition(from: input, startIndex: startIndex, currentIndex: index)),
                            message: "Invalid escape sequence '\\(nextChar)'",
                            suggestions: ["Use valid escape sequences like \\n, \\t, \\\\", "Escape backslash as \\\\"],
                            severity: .error,
                            context: "Only specific escape sequences are allowed in strings"
                        )
                        content.append(nextChar) // Include the character anyway
                        index = input.index(after: nextIndex)
                    }
                } else {
                    // Backslash at end of input
                    errorCollector.addError(
                        type: .invalidEscapeSequence("\\"),
                        range: SourceRange(at: TokenizerUtilities.sourcePosition(from: input, startIndex: startIndex, currentIndex: index)),
                        message: "Incomplete escape sequence at end of input",
                        suggestions: ["Complete the escape sequence", "Remove trailing backslash"],
                        severity: .error
                    )
                    index = nextIndex
                }
            } else {
                content.append(char)
                index = input.index(after: index)
            }
        }

        if !foundClosing {
            // Report unterminated string error
            errorCollector.addError(
                type: .unterminatedString,
                range: SourceRange(at: position),
                message: "Unterminated string literal",
                suggestions: ["Add closing quote \(quoteChar)", "Check for missing escape sequences"],
                severity: .error,
                context: "String literals must be properly closed"
            )
        }

        let lexeme = String(input[start..<index])
        let tokenType = TokenizerUtilities.stringLiteralTokenType(content: content)

        return TokenData(type: tokenType, lexeme: lexeme)
    }

    private func parseNumberWithRecovery(
        from input: String,
        at index: inout String.Index,
        startIndex: String.Index,
        errorCollector: ErrorCollector
    ) -> TokenData? {
        // First try normal number parsing
        let originalIndex = index
        if let token = parseNumber(from: input, at: &index) {
            return token
        }

        // Reset and try parsing as invalid number
        index = originalIndex
        if let invalidToken = parseInvalidNumber(from: input, at: &index, startIndex: startIndex, errorCollector: errorCollector) {
            return invalidToken
        }

        return nil
    }

    private func parseInvalidNumber(
        from input: String,
        at index: inout String.Index,
        startIndex: String.Index,
        errorCollector: ErrorCollector
    ) -> TokenData? {
        guard index < input.endIndex && (input[index].isNumber || input[index] == ".") else { return nil }

        let position = TokenizerUtilities.sourcePosition(from: input, startIndex: startIndex, currentIndex: index)
        var lexeme = ""

        // Try to collect what looks like a number, even if malformed
        while index < input.endIndex {
            let char = input[index]
            if char.isNumber || char == "." || char == "_" ||
               char == "e" || char == "E" || char == "+" || char == "-" ||
               char == "x" || char == "X" || char == "o" || char == "O" ||
               char == "b" || char == "B" || (char >= "a" && char <= "f") || (char >= "A" && char <= "F") {
                lexeme.append(char)
                index = input.index(after: index)
            } else {
                break
            }
        }

        // Check for specific invalid patterns
        if lexeme.filter({ $0 == "." }).count > 1 {
            // Multiple decimal points
            errorCollector.addError(
                type: .invalidNumberFormat(lexeme),
                range: SourceRange(position: position, length: lexeme.count),
                message: "Invalid number format '\(lexeme)' - multiple decimal points",
                suggestions: ["Use only one decimal point", "Check number syntax"],
                severity: .error,
                context: "Numbers can only have one decimal point"
            )
        } else if lexeme.contains("x") || lexeme.contains("X") {
            // Invalid hexadecimal
            let invalidChars = lexeme.filter { char in
                let isValidDigit = char.isNumber
                let isValidLowerHex = (char >= "a" && char <= "f")
                let isValidUpperHex = (char >= "A" && char <= "F")
                let isHexPrefix = (char == "x" || char == "X" || char == "0")
                return !(isValidDigit || isValidLowerHex || isValidUpperHex || isHexPrefix)
            }
            if !invalidChars.isEmpty {
                errorCollector.addError(
                    type: .invalidHexadecimalFormat,
                    range: SourceRange(position: position, length: lexeme.count),
                    message: "Invalid hexadecimal format '\(lexeme)'",
                    suggestions: ["Use only digits 0-9 and letters A-F for hexadecimal numbers", "Remove invalid characters"],
                    severity: .error,
                    context: "Hexadecimal numbers can only contain digits 0-9 and letters A-F"
                )
            }
        } else {
            // General invalid number format
            errorCollector.addError(
                type: .invalidNumberFormat(lexeme),
                range: SourceRange(position: position, length: lexeme.count),
                message: "Invalid number format '\(lexeme)'",
                suggestions: ["Check number syntax", "Remove invalid characters"],
                severity: .error,
                context: "Number format does not match expected pattern"
            )
        }

        // Return as identifier token since it's not a valid number
        return TokenData(type: .identifier, lexeme: lexeme)
    }

    private func parseNumberWithLenientRecovery(
        from input: String,
        at index: inout String.Index,
        startIndex: String.Index,
        errorCollector: ErrorCollector
    ) -> TokenData? {
        guard index < input.endIndex && (input[index].isNumber || input[index] == ".") else { return nil }

        let position = TokenizerUtilities.sourcePosition(from: input, startIndex: startIndex, currentIndex: index)
        var lexeme = ""

        // Try to collect what looks like a number, even if malformed
        while index < input.endIndex {
            let char = input[index]
            if char.isNumber || char == "." || char == "_" ||
               char == "e" || char == "E" || char == "+" || char == "-" ||
               char == "x" || char == "X" || char == "o" || char == "O" ||
               char == "b" || char == "B" || (char >= "a" && char <= "f") || (char >= "A" && char <= "F") {
                lexeme.append(char)
                index = input.index(after: index)
            } else {
                break
            }
        }

        // Report as invalid number format but still create a token
        errorCollector.addError(
            type: .invalidNumberFormat(lexeme),
            range: SourceRange(position: position, length: lexeme.count),
            message: "Invalid number format '\(lexeme)'",
            suggestions: ["Check number syntax", "Remove invalid characters"],
            severity: .error,
            context: "Number format does not match expected pattern"
        )

        // Return as identifier token since it's not a valid number
        return TokenData(type: .identifier, lexeme: lexeme)
    }

    private func performErrorRecovery(
        from input: String,
        at index: String.Index,
        errorCollector: ErrorCollector,
        position: SourcePosition
    ) -> String.Index {
        var newIndex = index

        // Skip to next whitespace or recognizable token
        while newIndex < input.endIndex {
            let char = input[newIndex]

            // Stop at whitespace
            if char.isWhitespace {
                break
            }

            // Stop at potential token boundaries
            if char == ";" || char == "," || char == "(" || char == ")" ||
               char == "{" || char == "}" || char == "[" || char == "]" {
                break
            }

            // Stop at start of what might be a keyword
            if TokenizerUtilities.isIdentifierStart(char) {
                // Look ahead to see if this might be a keyword
                let remainingInput = String(input[newIndex...])
                for (keyword, _) in TokenizerUtilities.keywords {
                    if remainingInput.hasPrefix(keyword) {
                        // Check word boundary
                        let endIndex = input.index(newIndex, offsetBy: keyword.count, limitedBy: input.endIndex) ?? input.endIndex
                        if endIndex == input.endIndex || !TokenizerUtilities.isIdentifierContinue(input[endIndex]) {
                            return newIndex // Found a keyword boundary
                        }
                    }
                }
            }

            newIndex = input.index(after: newIndex)
        }

        return newIndex
    }

    private func convertToLegacyError(_ enhancedError: EnhancedTokenizerError) -> TokenizerError {
        let position = enhancedError.range.start

        switch enhancedError.type {
        case .unexpectedCharacter(let char):
            return .unexpectedCharacter(char, position)
        case .unterminatedString:
            return .unterminatedString(position)
        case .unterminatedComment:
            return .unterminatedComment(position)
        case .invalidEscapeSequence:
            return .invalidEscapeSequence(position)
        case .invalidNumberFormat(let format):
            return .invalidNumberFormat(format, position)
        case .invalidDigitForBase(let digit, let base):
            return .invalidDigitForBase(digit, base, position)
        case .invalidUnderscorePlacement:
            return .invalidUnderscorePlacement(position)
        default:
            // For new error types, create a generic unexpected character error
            return .unexpectedCharacter(UnicodeScalar(0x00)!, position)
        }
    }

    // MARK: - Reuse existing parsing methods

    private func parseKeywordOrIdentifier(from input: String, at index: inout String.Index) -> TokenData? {
        // Use shared implementation for consistent behavior across all tokenizers
        guard let sharedTokenData = SharedTokenizerImplementation.parseKeywordOrIdentifier(from: input, at: &index) else { return nil }
        return TokenData(type: sharedTokenData.type, lexeme: sharedTokenData.lexeme)
    }

    private func parseKeyword(from input: String, at index: inout String.Index) -> TokenData? {
        // Use shared implementation for consistent behavior across all tokenizers
        guard let sharedTokenData = SharedTokenizerImplementation.parseKeyword(from: input, at: &index) else { return nil }
        return TokenData(type: sharedTokenData.type, lexeme: sharedTokenData.lexeme)
    }

    private func parseOperator(from input: String, at index: inout String.Index) -> TokenData? {
        // Use shared implementation for consistent behavior across all tokenizers
        guard let sharedTokenData = SharedTokenizerImplementation.parseOperator(from: input, at: &index) else { return nil }
        return TokenData(type: sharedTokenData.type, lexeme: sharedTokenData.lexeme)
    }

    private func parseDelimiter(from input: String, at index: inout String.Index) -> TokenData? {
        // Use shared implementation for consistent behavior across all tokenizers
        guard let sharedTokenData = SharedTokenizerImplementation.parseDelimiter(from: input, at: &index) else { return nil }
        return TokenData(type: sharedTokenData.type, lexeme: sharedTokenData.lexeme)
    }

    private func parseNumber(from input: String, at index: inout String.Index) -> TokenData? {
        // Use shared implementation for consistent behavior and enhanced error detection
        let originalIndex = index
        let result = SharedTokenizerImplementation.parseNumberWithValidation(from: input, at: &index)

        switch result {
        case .success(let sharedTokenData):
            return TokenData(type: sharedTokenData.type, lexeme: sharedTokenData.lexeme)
        case .failure:
            // Reset index for error recovery handling
            index = originalIndex
            return nil
        }
    }

    private func parseIdentifier(from input: String, at index: inout String.Index) -> TokenData? {
        // Use shared implementation for consistent behavior across all tokenizers
        guard let sharedTokenData = SharedTokenizerImplementation.parseIdentifier(from: input, at: &index) else { return nil }
        return TokenData(type: sharedTokenData.type, lexeme: sharedTokenData.lexeme)
    }
}

/// Data structure for token information (internal use)
private struct TokenData {
    let type: TokenType
    let lexeme: String
}
