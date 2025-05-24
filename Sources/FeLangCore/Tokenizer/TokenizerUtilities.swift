import Foundation

/// Shared utilities for tokenizer implementations to reduce code duplication
/// and ensure consistent behavior across different tokenizer strategies.
public enum TokenizerUtilities {

    // MARK: - Shared Constants

    /// Mapping of keywords to their token types
    /// Ordered with longer keywords first to ensure proper matching
    public static let keywords: [(String, TokenType)] = [
        // Japanese keywords (longest first)
        ("文字列型", .stringType),
        ("整数型", .integerType),
        ("実数型", .realType),
        ("文字型", .characterType),
        ("論理型", .booleanType),
        ("レコード", .recordType),
        ("配列", .arrayType),

        // English keywords (longest first)
        ("endprocedure", .endprocedureKeyword),
        ("endfunction", .endfunctionKeyword),
        ("endwhile", .endwhileKeyword),
        ("procedure", .procedureKeyword),
        ("function", .functionKeyword),
        ("endfor", .endforKeyword),
        ("endif", .endifKeyword),
        ("return", .returnKeyword),
        ("break", .breakKeyword),
        ("while", .whileKeyword),
        ("false", .falseKeyword),
        ("true", .trueKeyword),
        ("then", .thenKeyword),
        ("else", .elseKeyword),
        ("elif", .elifKeyword),
        ("step", .stepKeyword),
        ("and", .andKeyword),
        ("not", .notKeyword),
        ("for", .forKeyword),
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

    // MARK: - Character Classification

    /// Checks if a character can start an identifier
    /// Handles Unicode letters, underscore, and CJK characters robustly
    public static func isIdentifierStart(_ char: Character) -> Bool {
        return char.isLetter || char == "_" || isJapaneseCharacter(char)
    }

    /// Checks if a character can start an identifier (UnicodeScalar version)
    /// Handles Unicode letters, underscore, and CJK characters robustly
    public static func isIdentifierStart(_ scalar: UnicodeScalar) -> Bool {
        return scalar.isLetter || scalar == "_" || isJapaneseCharacter(scalar)
    }

    /// Checks if a character can continue an identifier
    /// Handles Unicode letters, digits, underscore, and CJK characters robustly
    public static func isIdentifierContinue(_ char: Character) -> Bool {
        return char.isLetter || char.isNumber || char == "_" || isJapaneseCharacter(char)
    }

    /// Checks if a character can continue an identifier (UnicodeScalar version)
    /// Handles Unicode letters, digits, underscore, and CJK characters robustly
    public static func isIdentifierContinue(_ scalar: UnicodeScalar) -> Bool {
        return scalar.isLetter || scalar.isNumber || scalar == "_" || isJapaneseCharacter(scalar)
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
}
