import Foundation

/// Specialized number parsing strategies for handling different number formats
/// and error recovery scenarios in tokenizer implementations.
public enum NumberParsingStrategies {

    // MARK: - Basic Number Parsing

    /// Parses decimal numbers with optional fractional part
    /// Supports formats like: 123, 123.456, .456
    public static func parseDecimalNumber(from input: String, at index: inout String.Index, start: String.Index) -> TokenizerParsingStrategies.TokenData? {
        var hasDecimal = false

        // Read integer part (if present)
        while index < input.endIndex && input[index].isNumber {
            index = input.index(after: index)
        }

        // Check for decimal point
        if index < input.endIndex && input[index] == "." {
            let nextIndex = input.index(after: index)
            if nextIndex < input.endIndex && input[nextIndex].isNumber {
                hasDecimal = true
                index = nextIndex

                // Read fractional part
                while index < input.endIndex && input[index].isNumber {
                    index = input.index(after: index)
                }
            }
        }

        let lexeme = String(input[start..<index])
        let tokenType = TokenizerUtilities.numberTokenType(hasDecimal: hasDecimal)
        return TokenizerParsingStrategies.TokenData(type: tokenType, lexeme: lexeme)
    }

    /// Parses hexadecimal numbers with 0x or 0X prefix
    /// Supports formats like: 0x1A2B, 0XFF, 0x123_ABC
    public static func parseHexadecimalNumber(from input: String, at index: inout String.Index, start: String.Index) -> TokenizerParsingStrategies.TokenData? {
        index = input.index(after: index) // consume '0'
        index = input.index(after: index) // consume 'x' or 'X'

        // Must have at least one hex digit
        guard index < input.endIndex,
              let firstScalar = String(input[index]).unicodeScalars.first,
              TokenizerUtilities.isHexDigit(firstScalar) || input[index] == "_" else {
            return nil
        }

        // Read hex digits and underscores
        while index < input.endIndex {
            if let scalar = String(input[index]).unicodeScalars.first,
               TokenizerUtilities.isHexDigit(scalar) || input[index] == "_" {
                index = input.index(after: index)
            } else {
                break
            }
        }

        let lexeme = String(input[start..<index])
        return TokenizerParsingStrategies.TokenData(type: .integerLiteral, lexeme: lexeme)
    }

    /// Parses binary numbers with 0b or 0B prefix  
    /// Supports formats like: 0b1010, 0B1111_0000
    public static func parseBinaryNumber(from input: String, at index: inout String.Index, start: String.Index) -> TokenizerParsingStrategies.TokenData? {
        index = input.index(after: index) // consume '0'
        index = input.index(after: index) // consume 'b' or 'B'

        // Must have at least one binary digit
        guard index < input.endIndex,
              let firstScalar = String(input[index]).unicodeScalars.first,
              TokenizerUtilities.isBinaryDigit(firstScalar) || input[index] == "_" else {
            return nil
        }

        // Read binary digits and underscores
        while index < input.endIndex {
            if let scalar = String(input[index]).unicodeScalars.first,
               TokenizerUtilities.isBinaryDigit(scalar) || input[index] == "_" {
                index = input.index(after: index)
            } else {
                break
            }
        }

        let lexeme = String(input[start..<index])
        return TokenizerParsingStrategies.TokenData(type: .integerLiteral, lexeme: lexeme)
    }

    /// Parses octal numbers with 0o or 0O prefix
    /// Supports formats like: 0o777, 0O123
    public static func parseOctalNumber(from input: String, at index: inout String.Index, start: String.Index) -> TokenizerParsingStrategies.TokenData? {
        index = input.index(after: index) // consume '0'
        index = input.index(after: index) // consume 'o' or 'O'

        // Must have at least one octal digit
        guard index < input.endIndex,
              let firstScalar = String(input[index]).unicodeScalars.first,
              TokenizerUtilities.isOctalDigit(firstScalar) || input[index] == "_" else {
            return nil
        }

        // Read octal digits and underscores
        while index < input.endIndex {
            if let scalar = String(input[index]).unicodeScalars.first,
               TokenizerUtilities.isOctalDigit(scalar) || input[index] == "_" {
                index = input.index(after: index)
            } else {
                break
            }
        }

        let lexeme = String(input[start..<index])
        return TokenizerParsingStrategies.TokenData(type: .integerLiteral, lexeme: lexeme)
    }

    // MARK: - Advanced Number Parsing

    /// Parses numbers with full support for all bases and scientific notation
    /// Automatically detects the base from prefixes (0x, 0b, 0o) and handles complex formats
    public static func parseAdvancedNumber(from input: String, at index: inout String.Index) -> TokenizerParsingStrategies.TokenData? {
        let start = index

        // Check for leading dot decimal
        if index < input.endIndex && input[index] == "." {
            let nextIndex = input.index(after: index)
            if nextIndex < input.endIndex && input[nextIndex].isNumber {
                index = nextIndex

                // Read fractional part (including underscores)
                while index < input.endIndex && (input[index].isNumber || input[index] == "_") {
                    index = input.index(after: index)
                }

                let lexeme = String(input[start..<index])
                return TokenizerParsingStrategies.TokenData(type: .realLiteral, lexeme: lexeme)
            } else {
                return nil
            }
        }

        // Must have at least one digit
        guard index < input.endIndex && input[index].isNumber else {
            return nil
        }

        // Check for alternative number bases (0x, 0b, 0o)
        if input[index] == "0" {
            let nextIndex = input.index(after: index)
            if nextIndex < input.endIndex {
                let nextChar = input[nextIndex]
                if nextChar == "x" || nextChar == "X" {
                    return parseHexadecimalNumber(from: input, at: &index, start: start)
                } else if nextChar == "b" || nextChar == "B" {
                    return parseBinaryNumber(from: input, at: &index, start: start)
                } else if nextChar == "o" || nextChar == "O" {
                    return parseOctalNumber(from: input, at: &index, start: start)
                }
            }
        }

        // Parse regular decimal number with potential scientific notation
        return parseDecimalNumberWithScientificNotation(from: input, at: &index, start: start)
    }

    /// Parses decimal numbers with scientific notation support
    /// Supports formats like: 1.23e10, 456E-7, 1e5
    private static func parseDecimalNumberWithScientificNotation(from input: String, at index: inout String.Index, start: String.Index) -> TokenizerParsingStrategies.TokenData? {
        var hasDecimal = false

        // Read integer part (including underscores)
        while index < input.endIndex && (input[index].isNumber || input[index] == "_") {
            index = input.index(after: index)
        }

        // Check for decimal point
        if index < input.endIndex && input[index] == "." {
            let nextIndex = input.index(after: index)
            if nextIndex < input.endIndex && (input[nextIndex].isNumber || input[nextIndex] == "_") {
                hasDecimal = true
                index = nextIndex

                // Read fractional part (including underscores)
                while index < input.endIndex && (input[index].isNumber || input[index] == "_") {
                    index = input.index(after: index)
                }
            }
        }

        // Check for scientific notation (e or E)
        if index < input.endIndex && (input[index] == "e" || input[index] == "E") {
            let eIndex = index
            index = input.index(after: index)

            // Optional sign
            if index < input.endIndex && (input[index] == "+" || input[index] == "-") {
                index = input.index(after: index)
            }

            // Must have at least one digit in exponent
            if index < input.endIndex && input[index].isNumber {
                hasDecimal = true // Scientific notation implies real number

                // Read exponent digits
                while index < input.endIndex && (input[index].isNumber || input[index] == "_") {
                    index = input.index(after: index)
                }
            } else {
                // Invalid scientific notation, backtrack
                index = eIndex
            }
        }

        let lexeme = String(input[start..<index])
        let tokenType = TokenizerUtilities.numberTokenType(hasDecimal: hasDecimal)
        return TokenizerParsingStrategies.TokenData(type: tokenType, lexeme: lexeme)
    }

    // MARK: - Error Recovery Number Parsing

    /// Parses potentially malformed numbers with error collection
    /// Attempts to extract meaningful tokens even from invalid number formats
    public static func parseNumberWithRecovery(
        from input: String,
        at index: inout String.Index,
        startIndex: String.Index,
        errorCollector: ErrorCollector
    ) -> TokenizerParsingStrategies.TokenData? {

        // First try normal parsing
        let originalIndex = index
        if let token = parseAdvancedNumber(from: input, at: &index) {
            return token
        }

        // Reset and attempt recovery parsing
        index = originalIndex
        return parseInvalidNumberWithRecovery(from: input, at: &index, startIndex: startIndex, errorCollector: errorCollector)
    }

    /// Handles malformed numbers and reports appropriate errors
    private static func parseInvalidNumberWithRecovery(
        from input: String,
        at index: inout String.Index,
        startIndex: String.Index,
        errorCollector: ErrorCollector
    ) -> TokenizerParsingStrategies.TokenData? {

        guard index < input.endIndex && (input[index].isNumber || input[index] == ".") else {
            return nil
        }

        let position = TokenizerUtilities.sourcePosition(from: input, startIndex: startIndex, currentIndex: index)
        var lexeme = ""

        // Collect what looks like a number, even if malformed
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

        // Analyze and report specific errors
        analyzeNumberErrors(lexeme: lexeme, position: position, errorCollector: errorCollector)

        // Return as identifier token since it's not a valid number
        return TokenizerParsingStrategies.TokenData(type: .identifier, lexeme: lexeme)
    }

    /// Analyzes malformed numbers and reports specific error types
    private static func analyzeNumberErrors(lexeme: String, position: SourcePosition, errorCollector: ErrorCollector) {
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
                    suggestions: ["Use only digits 0-9 and letters A-F", "Remove invalid characters"],
                    severity: .error,
                    context: "Hexadecimal numbers can only contain digits 0-9 and letters A-F"
                )
            }
        } else {
            // General invalid format
            errorCollector.addError(
                type: .invalidNumberFormat(lexeme),
                range: SourceRange(position: position, length: lexeme.count),
                message: "Invalid number format '\(lexeme)'",
                suggestions: ["Check number syntax", "Remove invalid characters"],
                severity: .error,
                context: "Number format does not match expected pattern"
            )
        }
    }

    // MARK: - Validation Utilities

    /// Validates a number format without parsing
    /// Useful for pre-validation and error prevention
    public static func isValidNumberFormat(_ lexeme: String) -> Bool {
        // Check for basic validity patterns
        if lexeme.isEmpty { return false }

        // Count decimal points
        let decimalCount = lexeme.filter { $0 == "." }.count
        if decimalCount > 1 { return false }

        // Check for valid start
        let firstChar = lexeme.first!
        if !(firstChar.isNumber || firstChar == ".") { return false }

        // Check for valid characters
        for char in lexeme {
            if !(char.isNumber || char == "." || char == "_" ||
                 char == "e" || char == "E" || char == "+" || char == "-" ||
                 char == "x" || char == "X" || char == "o" || char == "O" ||
                 char == "b" || char == "B" || (char >= "a" && char <= "f") ||
                 (char >= "A" && char <= "F")) {
                return false
            }
        }

        return true
    }

    /// Determines the expected number type from a lexeme
    /// Useful for validation and type checking
    public static func inferNumberType(from lexeme: String) -> TokenType {
        if lexeme.contains(".") || lexeme.contains("e") || lexeme.contains("E") {
            return .realLiteral
        } else {
            return .integerLiteral
        }
    }
}
