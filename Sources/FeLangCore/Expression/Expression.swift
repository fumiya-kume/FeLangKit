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

        if let value = dict["integer"]?.value as? Int {
            self = .integer(value)
        } else if let realValue = dict["real"]?.value {
            self = .real(try Self.decodeRealValue(realValue, decoder: decoder))
        } else if let value = dict["string"]?.value as? String {
            self = .string(value)
        } else if let value = dict["character"]?.value as? String, let char = value.first {
            self = .character(char)
        } else if let value = dict["boolean"]?.value as? Bool {
            self = .boolean(value)
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid literal value"))
        }
    }

    /// Decodes a real (floating-point) value from a generic `Any` type.
    /// - Parameters:
    ///   - value: The value to decode, expected to be of type `Double`, `Int`, or `NSNumber`.
    ///   - decoder: The `Decoder` instance used for decoding, primarily for error context.
    /// - Returns: A `Double` representation of the input value.
    /// - Throws: A `DecodingError` if the input value is not a numeric type.
    private static func decodeRealValue(_ value: Any, decoder: Decoder) throws -> Double {
        if let doubleValue = value as? Double {
            return doubleValue
        } else if let intValue = value as? Int {
            return Double(intValue)
        } else if let num = value as? NSNumber {
            return num.doubleValue
        } else {
            let actualType = type(of: value)
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Invalid literal value: expected a numeric type (Double or Int), but found \(actualType)"
            ))
        }
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
            do {
                let content = try StringEscapeUtilities.processEscapeSequences(rawContent)
                self = .string(content)
            } catch {
                // If escape sequence processing fails, return nil
                return nil
            }
        case .characterLiteral:
            // Remove the surrounding quotes, process escape sequences, and get the character
            let rawContent = token.lexeme.dropFirst().dropLast()
            do {
                let content = try StringEscapeUtilities.processEscapeSequences(String(rawContent))
                guard let character = content.first else { return nil }
                self = .character(character)
            } catch {
                // If escape sequence processing fails, return nil
                return nil
            }
        case .trueKeyword:
            self = .boolean(true)
        case .falseKeyword:
            self = .boolean(false)
        default:
            return nil
        }
    }

}
