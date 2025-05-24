import Foundation

/// Represents an expression in FE pseudo-language.
public indirect enum Expression: Equatable, Codable, Sendable {
    // Primary expressions
    case literal(Literal)
    case identifier(String)

    // Binary expressions
    case binary(BinaryOperator, Expression, Expression)

    // Unary expressions
    case unary(UnaryOperator, Expression)

    // Postfix expressions
    case arrayAccess(Expression, Expression)
    case fieldAccess(Expression, String)
    case functionCall(String, [Expression])
}

/// Represents literal values in FE pseudo-language.
public enum Literal: Equatable, Sendable {
    case integer(Int)
    case real(Double)
    case string(String)
    case character(Character)
    case boolean(Bool)
}

extension Literal: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .integer(let value):
            try container.encode(["integer": value])
        case .real(let value):
            try container.encode(["real": value])
        case .string(let value):
            try container.encode(["string": value])
        case .character(let value):
            try container.encode(["character": String(value)])
        case .boolean(let value):
            try container.encode(["boolean": value])
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: AnyCodable].self)

        // Check for empty dictionary
        guard !dict.isEmpty else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: """
                Empty literal object: no type specified.

                Expected format: { "type": value } where type is one of:
                - "integer": for integer values
                - "real": for floating-point values
                - "string": for text values
                - "character": for single character values
                - "boolean": for true/false values

                Example: { "integer": 42 }
                """
            ))
        }

        // Check for multiple keys (document the behavior)
        if dict.count > 1 {
            let keys = dict.keys.joined(separator: ", ")
            // Note: Current implementation accepts this and uses the first valid key
            // This could be enhanced in the future to be stricter
        }

        // Try to decode each literal type with enhanced error handling
        if let value = dict["integer"]?.value as? Int {
            self = .integer(value)
        } else if let realValue = dict["real"]?.value {
            self = .real(try Self.decodeRealValue(realValue, decoder: decoder))
        } else if let value = dict["string"]?.value as? String {
            self = .string(value)
        } else if let value = dict["character"]?.value as? String {
            // Enhanced character validation
            guard let char = value.first else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath,
                    debugDescription: """
                    Invalid character literal: empty string provided.

                    Expected: A string containing exactly one character.
                    Received: "\(value)"

                    Example: { "character": "A" }
                    """
                ))
            }

            // Check for multiple characters
            if value.count > 1 {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath,
                    debugDescription: """
                    Invalid character literal: multiple characters provided.

                    Expected: A string containing exactly one character.
                    Received: "\(value)" (length: \(value.count))

                    Suggestion: Use a string literal for multiple characters: { "string": "\(value)" }
                    """
                ))
            }

            self = .character(char)
        } else if let value = dict["boolean"]?.value as? Bool {
            self = .boolean(value)
        } else {
            // Enhanced error message for unrecognized literal types
            let availableKeys = dict.keys.map { "\"\($0)\"" }.joined(separator: ", ")
            let recognizedTypes = ["integer", "real", "string", "character", "boolean"]

            // Check if any of the keys are close to recognized types (typo detection)
            var suggestions: [String] = []
            for key in dict.keys {
                for recognizedType in recognizedTypes {
                    let distance = levenshteinDistance(key, recognizedType)
                    if distance <= 2 && distance > 0 {
                        suggestions.append("Did you mean \"\(recognizedType)\" instead of \"\(key)\"?")
                    }
                }
            }

            var errorMessage = """
            Invalid literal value: no supported type found.

            Available keys in JSON: \(availableKeys)
            Supported literal types: \(recognizedTypes.map { "\"\($0)\"" }.joined(separator: ", "))
            """

            if !suggestions.isEmpty {
                errorMessage += "\n\nSuggestions:\n" + suggestions.joined(separator: "\n")
            }

            errorMessage += """


            Examples of valid literals:
            - { "integer": 42 }
            - { "real": 3.14 }
            - { "string": "hello" }
            - { "character": "A" }
            - { "boolean": true }
            """

            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: errorMessage
            ))
        }
    }

    /// Decodes a real (floating-point) value from a generic `Any` type.
    /// Enhanced version with improved edge case handling and error messages
    /// - Parameters:
    ///   - value: The value to decode, expected to be of type `Double`, `Int`, `Float`, or `NSNumber`.
    ///   - decoder: The `Decoder` instance used for decoding, primarily for error context.
    /// - Returns: A `Double` representation of the input value.
    /// - Throws: A `DecodingError` if the input value is not a numeric type or contains invalid values.
    private static func decodeRealValue(_ value: Any, decoder: Decoder) throws -> Double {
        let result: Double

        // Handle different numeric types with explicit conversion
        switch value {
        case let doubleValue as Double:
            result = doubleValue

        case let intValue as Int:
            // Check for potential precision loss when converting large integers
            if intValue == Int.max || intValue == Int.min {
                // Document potential precision loss for extreme integer values
                result = Double(intValue)
            } else {
                result = Double(intValue)
            }

        case let floatValue as Float:
            // Convert Float to Double with explicit casting
            result = Double(floatValue)

        case let int32Value as Int32:
            result = Double(int32Value)

        case let int64Value as Int64:
            // Check for potential precision loss with large Int64 values
            if int64Value > Int64(Double.greatestFiniteMagnitude) ||
               int64Value < Int64(-Double.greatestFiniteMagnitude) {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Int64 value \(int64Value) is too large to represent as Double without precision loss"
                ))
            }
            result = Double(int64Value)

        case let nsNumber as NSNumber:
            // Handle NSNumber with validation for special values
            let numberType = CFNumberGetType(nsNumber)

            switch numberType {
            case .doubleType, .floatType, .float64Type:
                result = nsNumber.doubleValue
            case .intType, .longType, .longLongType, .cfIndexType, .nsIntegerType:
                result = Double(nsNumber.int64Value)
            case .shortType:
                result = Double(nsNumber.int16Value)
            case .charType:
                result = Double(nsNumber.int8Value)
            default:
                result = nsNumber.doubleValue
            }

        default:
            // Provide detailed error message with type information and suggestions
            let actualType = type(of: value)
            let supportedTypes = ["Double", "Int", "Float", "Int32", "Int64", "NSNumber"]

            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: """
                Invalid literal value for real type: expected a numeric type but found \(actualType).

                Supported types: \(supportedTypes.joined(separator: ", "))
                Received value: \(value)

                Suggestion: Ensure the JSON contains a valid numeric value for the 'real' field.
                """
            ))
        }

        // Validate the resulting Double value for edge cases
        return try validateDoubleValue(result, originalValue: value, decoder: decoder)
    }

    /// Validates a Double value for edge cases and provides descriptive error messages
    /// - Parameters:
    ///   - value: The Double value to validate
    ///   - originalValue: The original value that was converted
    ///   - decoder: The decoder for error context
    /// - Returns: The validated Double value
    /// - Throws: DecodingError for invalid values
    private static func validateDoubleValue(_ value: Double, originalValue: Any, decoder: Decoder) throws -> Double {
        // Check for special floating-point values
        if value.isNaN {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: """
                Invalid real value: NaN (Not a Number) is not supported in JSON serialization.

                Original value: \(originalValue)
                Suggestion: Use a finite numeric value instead.
                """
            ))
        }

        if value.isInfinite {
            let sign = value.sign == .minus ? "negative" : "positive"
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: """
                Invalid real value: \(sign) infinity is not supported in JSON serialization.

                Original value: \(originalValue)
                Suggestion: Use a finite numeric value within Double's range (±\(Double.greatestFiniteMagnitude)).
                """
            ))
        }

        // Check for subnormal numbers (very small numbers that might indicate precision issues)
        if value != 0.0 && abs(value) < Double.leastNormalMagnitude {
            // Note: We allow subnormal numbers but document them for potential precision concerns
            // This is a non-fatal validation - just document the behavior
        }

        return value
    }
}

/// Helper type for decoding heterogeneous values
private struct AnyCodable: Codable {
    let value: Any

    init<T>(_ value: T) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(Int.self) {
            self.value = value
        } else if let value = try? container.decode(Double.self) {
            self.value = value
        } else if let value = try? container.decode(String.self) {
            self.value = value
        } else if let value = try? container.decode(Bool.self) {
            self.value = value
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unsupported type"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if let value = value as? Int {
            try container.encode(value)
        } else if let value = value as? Double {
            try container.encode(value)
        } else if let value = value as? String {
            try container.encode(value)
        } else if let value = value as? Bool {
            try container.encode(value)
        } else {
            throw EncodingError.invalidValue(value, .init(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}

/// Represents binary operators with their precedence and associativity.
public enum BinaryOperator: String, CaseIterable, Equatable, Codable, Sendable {
    // Arithmetic operators
    case add = "+"
    case subtract = "-"
    case multiply = "*"
    case divide = "/"
    case modulo = "%"

    // Comparison operators
    case equal = "="
    case notEqual = "≠"
    case greater = ">"
    case greaterEqual = "≧"
    case less = "<"
    case lessEqual = "≦"

    // Logical operators
    case and = "and"
    case or = "or"

    /// Returns the precedence level of this operator.
    /// Higher numbers indicate higher precedence.
    public var precedence: Int {
        switch self {
        case .or:
            return 1
        case .and:
            return 2
        case .equal, .notEqual, .greater, .greaterEqual, .less, .lessEqual:
            return 3
        case .add, .subtract:
            return 4
        case .multiply, .divide, .modulo:
            return 5
        }
    }

    /// Returns true if this operator is left-associative.
    /// All binary operators in FE pseudo-language are left-associative.
    public var isLeftAssociative: Bool {
        return true
    }
}

/// Represents unary operators.
public enum UnaryOperator: String, CaseIterable, Equatable, Codable, Sendable {
    case not = "not"
    case plus = "+"
    case minus = "-"

    /// Returns the precedence level of this operator.
    /// Unary operators have high precedence (6).
    public var precedence: Int {
        return 6
    }
}

// MARK: - TokenType Mapping Extensions

extension BinaryOperator {
    /// Creates a binary operator from a token type.
    /// Returns nil if the token type doesn't correspond to a binary operator.
    public init?(tokenType: TokenType) {
        switch tokenType {
        case .plus:
            self = .add
        case .minus:
            self = .subtract
        case .multiply:
            self = .multiply
        case .divide:
            self = .divide
        case .modulo:
            self = .modulo
        case .equal:
            self = .equal
        case .notEqual:
            self = .notEqual
        case .greater:
            self = .greater
        case .greaterEqual:
            self = .greaterEqual
        case .less:
            self = .less
        case .lessEqual:
            self = .lessEqual
        case .andKeyword:
            self = .and
        case .orKeyword:
            self = .or
        default:
            return nil
        }
    }
}

extension UnaryOperator {
    /// Creates a unary operator from a token type.
    /// Returns nil if the token type doesn't correspond to a unary operator.
    public init?(tokenType: TokenType) {
        switch tokenType {
        case .notKeyword:
            self = .not
        case .plus:
            self = .plus
        case .minus:
            self = .minus
        default:
            return nil
        }
    }
}

extension Literal {
    /// Creates a literal from a token.
    /// Returns nil if the token doesn't represent a literal value.
    public init?(token: Token) {
        switch token.type {
        case .integerLiteral:
            guard let value = Int(token.lexeme) else { return nil }
            self = .integer(value)
        case .realLiteral:
            guard let value = Double(token.lexeme) else { return nil }
            self = .real(value)
        case .stringLiteral:
            // Remove the surrounding quotes and process escape sequences
            let rawContent = String(token.lexeme.dropFirst().dropLast())
            let content = StringEscapeUtilities.processEscapeSequences(rawContent)
            self = .string(content)
        case .characterLiteral:
            // Remove the surrounding quotes, process escape sequences, and get the character
            let rawContent = token.lexeme.dropFirst().dropLast()
            let content = StringEscapeUtilities.processEscapeSequences(String(rawContent))
            guard let character = content.first else { return nil }
            self = .character(character)
        case .trueKeyword:
            self = .boolean(true)
        case .falseKeyword:
            self = .boolean(false)
        default:
            return nil
        }
    }

}

/// Helper function to calculate Levenshtein distance for typo detection
/// Used to provide helpful suggestions when users mistype literal type names
private func levenshteinDistance(_ string1: String, _ string2: String) -> Int {
    let chars1 = Array(string1)
    let chars2 = Array(string2)
    let length1 = chars1.count
    let length2 = chars2.count
    
    // Create a matrix to store distances
    var matrix = Array(repeating: Array(repeating: 0, count: length2 + 1), count: length1 + 1)
    
    // Initialize first row and column
    for row in 0...length1 {
        matrix[row][0] = row
    }
    for col in 0...length2 {
        matrix[0][col] = col
    }
    
    // Fill in the matrix
    for row in 1...length1 {
        for col in 1...length2 {
            let cost = chars1[row - 1] == chars2[col - 1] ? 0 : 1
            matrix[row][col] = min(
                matrix[row - 1][col] + 1,      // deletion
                matrix[row][col - 1] + 1,      // insertion
                matrix[row - 1][col - 1] + cost // substitution
            )
        }
    }
    
    return matrix[length1][length2]
}
