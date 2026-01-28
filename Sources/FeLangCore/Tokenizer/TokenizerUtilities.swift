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
        ("endclass", .endclassKeyword),
        ("continue", .continueKeyword),

        // 6 characters
        ("elseif", .elseifKeyword),
        ("return", .returnKeyword),
        ("endfor", .endforKeyword),

        // 5 characters
        ("class", .classKeyword),

        // 5 characters
        ("endif", .endifKeyword),
        ("break", .breakKeyword),
        ("while", .whileKeyword),
        ("false", .falseKeyword),

        // 4 characters - Japanese and English mixed by length
        ("\u{6587}\u{5B57}\u{5217}\u{578B}", .stringType),
        ("\u{30EC}\u{30B3}\u{30FC}\u{30C9}", .recordType),
        ("true", .trueKeyword),
        ("then", .thenKeyword),
        ("else", .elseKeyword),
        ("elif", .elifKeyword),
        ("step", .stepKeyword),

        // 3 characters
        ("\u{6574}\u{6570}\u{578B}", .integerType),
        ("\u{5B9F}\u{6570}\u{578B}", .realType),
        ("\u{6587}\u{5B57}\u{578B}", .characterType),
        ("\u{8AD6}\u{7406}\u{578B}", .booleanType),
        ("and", .andKeyword),
        ("not", .notKeyword),
        ("mod", .modKeyword),
        ("for", .forKeyword),

        // 3 characters (Japanese)
        ("\u{672A}\u{5B9A}\u{7FA9}", .undefinedKeyword),

        // 2 characters
        ("\u{914D}\u{5217}", .arrayType),
        ("\u{5909}\u{6570}", .variableKeyword),
        ("\u{5B9A}\u{6570}", .constantKeyword),
        ("\u{5927}\u{57DF}", .globalKeyword),
        ("\u{307E}\u{3067}", .toKeyword),
        ("\u{305A}\u{3064}", .stepKeyword),
        ("or", .orKeyword),
        ("to", .toKeyword),
        ("in", .inKeyword),
        ("do", .doKeyword),
        ("if", .ifKeyword)
    ]

    /// Mapping of keywords to their token types (for O(1) lookup)
    public static let keywordMap: [String: TokenType] = Dictionary(keywords, uniquingKeysWith: { _, new in new })

    /// Pre-cached keyword lexeme strings to reuse canonical String instances.
    /// Avoids retaining freshly-allocated lexeme copies when a keyword is matched.
    public static let keywordLexemeMap: [String: String] = Dictionary(uniqueKeysWithValues: keywords.map { ($0.0, $0.0) })

    /// Operator definitions with their token types
    /// Ordered with longer operators first to ensure proper matching
    public static let operators: [(String, TokenType)] = [
        ("\u{2190}", .assign),
        ("!=", .notEqual),
        ("\u{2260}", .notEqual),
        (">=", .greaterEqual),
        ("<=", .lessEqual),
        ("<<", .leftShift),
        (">>", .rightShift),
        ("\u{2267}", .greaterEqual),
        ("\u{2266}", .lessEqual),
        ("+", .plus),
        ("-", .minus),
        ("*", .multiply),
        ("/", .divide),
        ("\u{00F7}", .divide),
        ("%", .modulo),
        ("=", .equal),
        (">", .greater),
        ("<", .less),
        ("\u{2227}", .bitwiseAnd),
        ("\u{2228}", .bitwiseOr),
        // NOTE: If multi-character operators starting with "!" (e.g., "!=") are added,
        // they must appear before this single-character "!" entry to preserve longest-match behavior.
        ("!", .notKeyword)
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

    /// Lookup map for operator first characters -> candidate operators (longest first)
    public static let operatorFirstCharMap: [Character: [(String, TokenType)]] = {
        var map: [Character: [(String, TokenType)]] = [:]
        for (opString, tokenType) in operators {
            guard let firstChar = opString.first else { continue }
            map[firstChar, default: []].append((opString, tokenType))
        }
        for key in map.keys {
            map[key]?.sort { $0.0.count > $1.0.count }
        }
        return map
    }()

    /// Direct lookup for single-character delimiters.
    /// Assumes all delimiters are single-character; multi-character delimiters
    /// would only be matched by their first character, which is incorrect.
    public static let delimiterMap: [Character: TokenType] = {
        assert(delimiters.allSatisfy { $0.0.count == 1 }, "delimiterMap assumes single-character delimiters")
        return Dictionary(uniqueKeysWithValues: delimiters.compactMap { delimiter, tokenType in
            delimiter.first.map { ($0, tokenType) }
        })
    }()

    /// Pre-cached delimiter lexeme strings to avoid per-token String allocation.
    /// Maps each delimiter character to its canonical String representation.
    public static let delimiterLexemeMap: [Character: String] = Dictionary(
        uniqueKeysWithValues: delimiters.compactMap { delimiter, _ in
            delimiter.first.map { ($0, delimiter) }
        }
    )

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
        let value = scalar.value
        // Fast path for ASCII
        if value == 0x5F { return true } // '_'
        if (value >= 0x41 && value <= 0x5A) ||
           (value >= 0x61 && value <= 0x7A) { return true } // A-Z, a-z
        if value < 0x80 { return false } // Other ASCII cannot start identifiers

        // Slow path: full Unicode classification for non-ASCII
        let classification = UnicodeNormalizer.classifyCharacter(scalar)
        switch classification {
        case .letter, .other(subcategory: .privateUse):
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
        let value = scalar.value
        // Fast path for ASCII
        if value == 0x5F { return true } // '_'
        if (value >= 0x41 && value <= 0x5A) ||
           (value >= 0x61 && value <= 0x7A) { return true } // A-Z, a-z
        if value >= 0x30 && value <= 0x39 { return true } // 0-9
        if value < 0x80 { return false } // Other ASCII cannot continue identifiers

        // Slow path: full Unicode classification for non-ASCII
        let classification = UnicodeNormalizer.classifyCharacter(scalar)
        switch classification {
        case .letter, .number, .mark(subcategory: .nonspacingMark), .other(subcategory: .privateUse):
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
        var inputIndex = index
        for targetChar in target {
            guard inputIndex < input.endIndex, input[inputIndex] == targetChar else {
                return false
            }
            inputIndex = input.index(after: inputIndex)
        }
        return true
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

    // MARK: - Position Tracking

    /// Tracks source position incrementally during tokenization.
    /// Provides O(1) position queries instead of O(n) recomputation.
    public struct PositionTracker {
        private var line: Int = 1
        private var column: Int = 1
        private var offset: Int = 0

        public init() {}

        /// Returns the current source position.
        public var currentPosition: SourcePosition {
            return SourcePosition(line: line, column: column, offset: offset)
        }

        /// Advances the tracker by one character.
        public mutating func advance(past character: Character) {
            if character == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
            offset += character.unicodeScalars.count
        }

        /// Advances the tracker through a substring.
        public mutating func advance(through substring: Substring) {
            for char in substring {
                advance(past: char)
            }
        }
    }

    // MARK: - Position Calculation

    /// Calculates source position from string indices
    public static func sourcePosition(from input: String, startIndex: String.Index, currentIndex: String.Index) -> SourcePosition {
        let processed = String(input[startIndex..<currentIndex])
        let lines = processed.components(separatedBy: "\n")
        let line = lines.count
        let column = (lines.last?.count ?? 0) + 1
        let offset = input.unicodeScalars.distance(from: startIndex, to: currentIndex)

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

    /// Validates underscore placement in numbers (not at start, end, or adjacent to special characters)
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

        // Cannot be adjacent to underscores, decimal points, exponent indicators, or signs
        let invalidAdjacent: Set<UnicodeScalar> = ["_", ".", "e", "E", "+", "-"]
        if let prev = previousChar, invalidAdjacent.contains(prev) { return false }
        if let next = nextChar, invalidAdjacent.contains(next) { return false }

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

    /// Validates a number format with the given base prefix and digit validator.
    private static func validateBaseNumber(
        _ input: String,
        lowercasePrefix: String,
        uppercasePrefix: String,
        baseName: String,
        isValidDigit: (UnicodeScalar) -> Bool
    ) throws {
        guard input.hasPrefix(lowercasePrefix) || input.hasPrefix(uppercasePrefix) else {
            throw TokenizerError.invalidNumberFormat(input, SourcePosition(line: 1, column: 1, offset: 0))
        }

        let digits = String(input.dropFirst(2))
        guard !digits.isEmpty else {
            throw TokenizerError.invalidNumberFormat(input, SourcePosition(line: 1, column: 3, offset: 2))
        }

        for (index, char) in digits.unicodeScalars.enumerated() where char != "_" && !isValidDigit(char) {
            throw TokenizerError.invalidDigitForBase(
                String(char), baseName,
                SourcePosition(line: 1, column: 3 + index, offset: 2 + index)
            )
        }
    }

    /// Validates a hexadecimal number format
    public static func validateHexadecimalNumber(_ input: String) throws {
        try validateBaseNumber(input, lowercasePrefix: "0x", uppercasePrefix: "0X",
                              baseName: "hexadecimal", isValidDigit: isHexDigit)
    }

    /// Validates a binary number format
    public static func validateBinaryNumber(_ input: String) throws {
        try validateBaseNumber(input, lowercasePrefix: "0b", uppercasePrefix: "0B",
                              baseName: "binary", isValidDigit: isBinaryDigit)
    }

    /// Validates an octal number format
    public static func validateOctalNumber(_ input: String) throws {
        try validateBaseNumber(input, lowercasePrefix: "0o", uppercasePrefix: "0O",
                              baseName: "octal", isValidDigit: isOctalDigit)
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
