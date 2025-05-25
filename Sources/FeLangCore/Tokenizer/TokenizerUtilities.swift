import Foundation

/// Shared utilities for tokenizer implementations to reduce code duplication
/// and ensure consistent behavior across different tokenizer strategies.
public enum TokenizerUtilities {

    // MARK: - Shared Constants

    /// Mapping of keywords to their token types
    /// Ordered with longer keywords first to ensure proper matching
    /// Note: Current tokenizers extract complete identifiers first, so this ordering
    /// is for consistency and future-proofing rather than functional necessity
    public static let keywords: [(String, TokenType)] = [
        // 12 characters
        ("endprocedure", .endprocedureKeyword),

        // 11 characters  
        ("endfunction", .endfunctionKeyword),

        // 9 characters
        ("procedure", .procedureKeyword),

        // 8 characters
        ("endwhile", .endwhileKeyword),
        ("function", .functionKeyword),

        // 6 characters
        ("return", .returnKeyword),
        ("endfor", .endforKeyword),

        // 5 characters
        ("endif", .endifKeyword),
        ("break", .breakKeyword),
        ("while", .whileKeyword),
        ("false", .falseKeyword),

        // 4 characters - Japanese and English mixed by length
        ("文字列型", .stringType),
        ("レコード", .recordType),
        ("true", .trueKeyword),
        ("then", .thenKeyword),
        ("else", .elseKeyword),
        ("elif", .elifKeyword),
        ("step", .stepKeyword),

        // 3 characters
        ("整数型", .integerType),
        ("実数型", .realType),
        ("文字型", .characterType),
        ("論理型", .booleanType),
        ("and", .andKeyword),
        ("not", .notKeyword),
        ("for", .forKeyword),

        // 2 characters
        ("配列", .arrayType),
        ("変数", .variableKeyword),
        ("定数", .constantKeyword),
        ("or", .orKeyword),
        ("to", .toKeyword),
        ("in", .inKeyword),
        ("do", .doKeyword),
        ("if", .ifKeyword)
    ]

    /// Mapping of keywords to their token types (for O(1) lookup)
    public static let keywordMap: [String: TokenType] = {
        var map: [String: TokenType] = [:]
        for (keyword, tokenType) in keywords {
            map[keyword] = tokenType
        }
        return map
    }()

    /// Operator definitions with their token types
    /// Ordered with longer operators first to ensure proper matching
    public static let operators: [(String, TokenType)] = [
        ("←", .assign),
        ("≠", .notEqual),
        ("≧", .greaterEqual),
        ("≦", .lessEqual),
        ("+", .plus),
        ("-", .minus),
        ("*", .multiply),
        ("/", .divide),
        ("%", .modulo),
        ("=", .equal),
        (">", .greater),
        ("<", .less)
    ]

    /// Delimiter definitions with their token types
    public static let delimiters: [(String, TokenType)] = [
        ("(", .leftParen),
        (")", .rightParen),
        ("[", .leftBracket),
        ("]", .rightBracket),
        ("{", .leftBrace),
        ("}", .rightBrace),
        (",", .comma),
        (".", .dot),
        (";", .semicolon),
        (":", .colon)
    ]

    // MARK: - Whitespace Utilities

    /// Checks if a character is whitespace (including full-width space)
    /// Supports standard ASCII whitespace and Japanese full-width space (U+3000)
    /// This helper provides consistent whitespace handling across all tokenizers
    public static func isWhitespace(_ char: UnicodeScalar) -> Bool {
        return char == " " || char == "\t" || char == "\u{3000}"
    }

    /// Checks if a character is whitespace (Character version)
    /// Supports standard ASCII whitespace and Japanese full-width space (U+3000)  
    /// This helper provides consistent whitespace handling across all tokenizers
    /// For multi-scalar characters, all scalars must be whitespace
    public static func isWhitespace(_ char: Character) -> Bool {
        guard !char.unicodeScalars.isEmpty else { return false }
        // For multi-scalar characters (like combined marks), all scalars must be whitespace
        return char.unicodeScalars.allSatisfy(isWhitespace)
    }

    // MARK: - Character Classification

    /// Checks if a character can start an identifier
    /// Handles Unicode letters, underscore, and extended character sets robustly
    /// Uses enhanced Unicode character classification for comprehensive support
    public static func isIdentifierStart(_ char: Character) -> Bool {
        guard let scalar = char.unicodeScalars.first else { return false }
        return isIdentifierStart(scalar)
    }

    /// Checks if a character can start an identifier (UnicodeScalar version)
    /// Handles Unicode letters, underscore, and extended character sets robustly
    /// Uses enhanced Unicode character classification for comprehensive support
    public static func isIdentifierStart(_ scalar: UnicodeScalar) -> Bool {
        // Basic identifier start characters
        if scalar == "_" {
            return true
        }

        // Use enhanced character classification
        let classification = UnicodeNormalizer.classifyCharacter(scalar)
        switch classification {
        case .letter:
            return true
        case .other(subcategory: .privateUse):
            // Allow Private Use Area (U+E000–U+F8FF) for custom domain-specific symbols.
            // This enables FeLang to support specialized characters in specific contexts,
            // such as mathematical notation, proprietary symbols, or legacy character sets
            // while maintaining compatibility with Unicode standards.
            return true
        default:
            return false
        }
    }

    /// Checks if a character can continue an identifier
    /// Handles Unicode letters, digits, underscore, and extended character sets robustly  
    /// Uses enhanced Unicode character classification for comprehensive support
    public static func isIdentifierContinue(_ char: Character) -> Bool {
        guard let scalar = char.unicodeScalars.first else { return false }
        return isIdentifierContinue(scalar)
    }

    /// Checks if a character can continue an identifier (UnicodeScalar version)
    /// Handles Unicode letters, digits, underscore, and extended character sets robustly
    /// Uses enhanced Unicode character classification for comprehensive support
    public static func isIdentifierContinue(_ scalar: UnicodeScalar) -> Bool {
        // Basic identifier continuation characters
        if scalar == "_" {
            return true
        }

        // Use enhanced character classification
        let classification = UnicodeNormalizer.classifyCharacter(scalar)
        switch classification {
        case .letter, .number:
            return true
        case .mark(subcategory: .nonspacingMark):
            // Allow combining marks in identifiers
            return true
        case .other(subcategory: .privateUse):
            // Allow Private Use Area (U+E000–U+F8FF) for custom domain-specific symbols.
            // This enables FeLang to support specialized characters in specific contexts,
            // such as mathematical notation, proprietary symbols, or legacy character sets
            // while maintaining compatibility with Unicode standards.
            return true
        default:
            return false
        }
    }

    /// Checks if a character is a Japanese character (Hiragana, Katakana, or Kanji)
    /// Includes comprehensive Unicode ranges for CJK characters
    public static func isJapaneseCharacter(_ char: Character) -> Bool {
        guard let scalar = char.unicodeScalars.first else { return false }
        return isJapaneseCharacter(scalar)
    }

    /// Checks if a Unicode scalar is a Japanese character (Hiragana, Katakana, or Kanji)
    /// Includes comprehensive Unicode ranges for CJK characters
    public static func isJapaneseCharacter(_ scalar: UnicodeScalar) -> Bool {
        let value = scalar.value
        return (value >= 0x3040 && value <= 0x309F) ||  // Hiragana
               (value >= 0x30A0 && value <= 0x30FF) ||  // Katakana
               (value >= 0x4E00 && value <= 0x9FAF) ||  // CJK Unified Ideographs (main block)
               (value >= 0x3400 && value <= 0x4DBF) ||  // CJK Extension A
               (value >= 0x20000 && value <= 0x2A6DF)   // CJK Extension B
    }

    // MARK: - String Matching Utilities

    /// Checks if a target string matches at the given index in the input
    public static func matchString(_ target: String, in input: String, at index: String.Index) -> Bool {
        guard let endIndex = input.index(index, offsetBy: target.count, limitedBy: input.endIndex) else {
            return false
        }
        return String(input[index..<endIndex]) == target
    }

    /// Checks if a target string matches at the given index in the Unicode scalar view
    public static func matchString(_ target: String, in source: String.UnicodeScalarView, at index: String.UnicodeScalarView.Index) -> Bool {
        var currentIndex = index
        for targetScalar in target.unicodeScalars {
            guard currentIndex < source.endIndex && source[currentIndex] == targetScalar else {
                return false
            }
            currentIndex = source.index(after: currentIndex)
        }
        return true
    }

    // MARK: - Position Calculation

    /// Calculates source position from string indices
    public static func sourcePosition(from input: String, startIndex: String.Index, currentIndex: String.Index) -> SourcePosition {
        let processed = String(input[startIndex..<currentIndex])
        let lines = processed.components(separatedBy: "\n")
        let line = lines.count
        let column = (lines.last?.count ?? 0) + 1
        let offset = input.distance(from: startIndex, to: currentIndex)

        return SourcePosition(line: line, column: column, offset: offset)
    }

    // MARK: - Token Type Determination

    /// Determines if a string literal should be a character or string token
    public static func stringLiteralTokenType(content: String) -> TokenType {
        return content.count == 1 ? .characterLiteral : .stringLiteral
    }

    /// Determines if a number should be an integer or real token
    public static func numberTokenType(hasDecimal: Bool) -> TokenType {
        return hasDecimal ? .realLiteral : .integerLiteral
    }

    // MARK: - Validation Utilities

    /// Validates that a keyword match is at a word boundary
    public static func isValidKeywordBoundary(in input: String, at endIndex: String.Index) -> Bool {
        return endIndex == input.endIndex || !isIdentifierContinue(input[endIndex])
    }

    /// Validates that a keyword match is at a word boundary (UnicodeScalar version)
    public static func isValidKeywordBoundary(in source: String.UnicodeScalarView, at endIndex: String.UnicodeScalarView.Index) -> Bool {
        return endIndex == source.endIndex || !isIdentifierContinue(source[endIndex])
    }

    // MARK: - Advanced Number Parsing Utilities

    /// Determines if a character is a valid hex digit
    public static func isHexDigit(_ char: UnicodeScalar) -> Bool {
        return (char.value >= 0x30 && char.value <= 0x39) || // 0-9
               (char.value >= 0x41 && char.value <= 0x46) || // A-F
               (char.value >= 0x61 && char.value <= 0x66)    // a-f
    }

    /// Determines if a character is a valid binary digit
    public static func isBinaryDigit(_ char: UnicodeScalar) -> Bool {
        return char == "0" || char == "1"
    }

    /// Determines if a character is a valid octal digit
    public static func isOctalDigit(_ char: UnicodeScalar) -> Bool {
        return char.value >= 0x30 && char.value <= 0x37 // 0-7
    }

    /// Validates underscore placement in numbers (not at start, end, or consecutive)
    public static func isValidUnderscorePlacement(
        at position: Int,
        in numberString: String,
        previousChar: UnicodeScalar?,
        nextChar: UnicodeScalar?
    ) -> Bool {
        // Cannot be at start or end
        if position == 0 || position == numberString.count - 1 {
            return false
        }

        // Cannot be consecutive underscores
        if previousChar == "_" || nextChar == "_" {
            return false
        }

        // Cannot be adjacent to decimal point
        if previousChar == "." || nextChar == "." {
            return false
        }

        // Cannot be adjacent to exponent indicator
        if previousChar == "e" || previousChar == "E" ||
           nextChar == "e" || nextChar == "E" {
            return false
        }

        // Cannot be adjacent to sign in exponent
        if previousChar == "+" || previousChar == "-" ||
           nextChar == "+" || nextChar == "-" {
            return false
        }

        return true
    }

    /// Validates and cleans a number string by removing valid underscores
    public static func validateAndCleanNumber(_ input: String) throws -> String {
        guard !input.isEmpty else {
            throw TokenizerError.invalidNumberFormat(input, SourcePosition(line: 1, column: 1, offset: 0))
        }

        var cleaned = ""
        let scalars = Array(input.unicodeScalars)

        for (index, scalar) in scalars.enumerated() {
            if scalar == "_" {
                let prevChar = index > 0 ? scalars[index - 1] : nil
                let nextChar = index < scalars.count - 1 ? scalars[index + 1] : nil

                guard isValidUnderscorePlacement(at: index, in: input,
                                               previousChar: prevChar,
                                               nextChar: nextChar) else {
                    throw TokenizerError.invalidUnderscorePlacement(SourcePosition(line: 1, column: index + 1, offset: index))
                }
                // Skip underscores in cleaned string
            } else {
                cleaned.append(Character(scalar))
            }
        }

        return cleaned
    }

    /// Validates a scientific notation number format
    public static func validateScientificNotation(_ input: String) throws {
        let parts = input.lowercased().components(separatedBy: "e")

        guard parts.count == 2 else {
            throw TokenizerError.invalidNumberFormat(input, SourcePosition(line: 1, column: 1, offset: 0))
        }

        let mantissa = parts[0]
        let exponent = parts[1]

        // Validate mantissa (can be integer or decimal)
        guard !mantissa.isEmpty &&
              (mantissa.allSatisfy { $0.isNumber || $0 == "." || $0 == "_" }) else {
            throw TokenizerError.invalidNumberFormat(input, SourcePosition(line: 1, column: 1, offset: 0))
        }

        // Validate exponent (can start with + or - followed by digits)
        var expIndex = 0
        let expScalars = Array(exponent.unicodeScalars)

        if !expScalars.isEmpty && (expScalars[0] == "+" || expScalars[0] == "-") {
            expIndex = 1
        }

        guard expIndex < expScalars.count else {
            throw TokenizerError.invalidNumberFormat(input, SourcePosition(line: 1, column: mantissa.count + 2, offset: mantissa.count + 1))
        }

        for index in expIndex..<expScalars.count {
            let scalar = expScalars[index]
            guard (scalar.value >= 0x30 && scalar.value <= 0x39) || scalar == "_" else { // 0-9 or underscore
                throw TokenizerError.invalidNumberFormat(input, SourcePosition(line: 1, column: mantissa.count + 2 + index, offset: mantissa.count + 1 + index))
            }
        }
    }

    /// Validates a hexadecimal number format
    public static func validateHexadecimalNumber(_ input: String) throws {
        guard input.hasPrefix("0x") || input.hasPrefix("0X") else {
            throw TokenizerError.invalidNumberFormat(input, SourcePosition(line: 1, column: 1, offset: 0))
        }

        let digits = String(input.dropFirst(2))
        guard !digits.isEmpty else {
            throw TokenizerError.invalidNumberFormat(input, SourcePosition(line: 1, column: 3, offset: 2))
        }

        for (index, char) in digits.unicodeScalars.enumerated() {
            if char != "_" && !isHexDigit(char) {
                throw TokenizerError.invalidDigitForBase(String(char), "hexadecimal", SourcePosition(line: 1, column: 3 + index, offset: 2 + index))
            }
        }
    }

    /// Validates a binary number format
    public static func validateBinaryNumber(_ input: String) throws {
        guard input.hasPrefix("0b") || input.hasPrefix("0B") else {
            throw TokenizerError.invalidNumberFormat(input, SourcePosition(line: 1, column: 1, offset: 0))
        }

        let digits = String(input.dropFirst(2))
        guard !digits.isEmpty else {
            throw TokenizerError.invalidNumberFormat(input, SourcePosition(line: 1, column: 3, offset: 2))
        }

        for (index, char) in digits.unicodeScalars.enumerated() {
            if char != "_" && !isBinaryDigit(char) {
                throw TokenizerError.invalidDigitForBase(String(char), "binary", SourcePosition(line: 1, column: 3 + index, offset: 2 + index))
            }
        }
    }

    /// Validates an octal number format
    public static func validateOctalNumber(_ input: String) throws {
        guard input.hasPrefix("0o") || input.hasPrefix("0O") else {
            throw TokenizerError.invalidNumberFormat(input, SourcePosition(line: 1, column: 1, offset: 0))
        }

        let digits = String(input.dropFirst(2))
        guard !digits.isEmpty else {
            throw TokenizerError.invalidNumberFormat(input, SourcePosition(line: 1, column: 3, offset: 2))
        }

        for (index, char) in digits.unicodeScalars.enumerated() {
            if char != "_" && !isOctalDigit(char) {
                throw TokenizerError.invalidDigitForBase(String(char), "octal", SourcePosition(line: 1, column: 3 + index, offset: 2 + index))
            }
        }
    }

    /// Determines the appropriate token type for enhanced numbers
    public static func enhancedNumberTokenType(lexeme: String) -> TokenType {
        let lowercased = lexeme.lowercased()

        // Scientific notation is always real
        if lowercased.contains("e") {
            return .realLiteral
        }

        // Alternative bases are always integers
        if lowercased.hasPrefix("0x") || lowercased.hasPrefix("0b") || lowercased.hasPrefix("0o") {
            return .integerLiteral
        }

        // Check for decimal point
        if lexeme.contains(".") {
            return .realLiteral
        }

        return .integerLiteral
    }
}

// MARK: - Extensions for UnicodeScalar

extension UnicodeScalar {
    /// Returns true if this scalar represents a letter
    var isLetter: Bool {
        return CharacterSet.letters.contains(self)
    }

    /// Returns true if this scalar represents a number
    var isNumber: Bool {
        return CharacterSet.decimalDigits.contains(self)
    }

    /// Returns true if this scalar represents punctuation
    var isPunctuation: Bool {
        return CharacterSet.punctuationCharacters.contains(self)
    }

    /// Returns true if this scalar represents a symbol
    var isSymbol: Bool {
        return CharacterSet.symbols.contains(self)
    }

    /// Returns true if this scalar represents whitespace
    var isWhitespace: Bool {
        return CharacterSet.whitespacesAndNewlines.contains(self)
    }

    /// Returns true if this scalar is uppercase
    var isUppercase: Bool {
        return CharacterSet.uppercaseLetters.contains(self)
    }

    /// Returns true if this scalar is lowercase
    var isLowercase: Bool {
        return CharacterSet.lowercaseLetters.contains(self)
    }
}
