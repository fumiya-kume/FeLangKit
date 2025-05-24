/// Represents the different types of tokens in FE pseudo-language.
public enum TokenType: String, CaseIterable, Equatable, Codable, Sendable {
    // MARK: - Keywords

    /// Data type keywords
    case integerType = "整数型"
    case realType = "実数型"
    case characterType = "文字型"
    case stringType = "文字列型"
    case booleanType = "論理型"
    case recordType = "レコード"
    case arrayType = "配列"

    /// Control flow keywords
    case ifKeyword = "if"
    case whileKeyword = "while"
    case forKeyword = "for"
    case returnKeyword = "return"
    case breakKeyword = "break"

    /// Logical keywords
    case andKeyword = "and"
    case orKeyword = "or"
    case notKeyword = "not"

    /// Boolean literals
    case trueKeyword = "true"
    case falseKeyword = "false"

    // MARK: - Literals

    case integerLiteral
    case realLiteral
    case stringLiteral
    case characterLiteral

    // MARK: - Identifiers

    case identifier

    // MARK: - Operators

    /// Arithmetic operators
    case plus = "+"
    case minus = "-"
    case multiply = "*"
    case divide = "/"
    case modulo = "%"

    /// Assignment operator
    case assign = "←"

    /// Comparison operators
    case equal = "="
    case notEqual = "≠"
    case greater = ">"
    case greaterEqual = "≧"
    case less = "<"
    case lessEqual = "≦"

    // MARK: - Delimiters

    case leftParen = "("
    case rightParen = ")"
    case leftBracket = "["
    case rightBracket = "]"
    case leftBrace = "{"
    case rightBrace = "}"
    case comma = ","
    case dot = "."
    case semicolon = ";"
    case colon = ":"

    // MARK: - Special

    case comment
    case whitespace
    case newline
    case eof
    case invalid
}

extension TokenType {
    /// Returns true if this token type represents a keyword.
    public var isKeyword: Bool {
        switch self {
        case .integerType, .realType, .characterType, .stringType, .booleanType,
             .recordType, .arrayType, .ifKeyword, .whileKeyword, .forKeyword,
             .andKeyword, .orKeyword, .notKeyword, .returnKeyword, .breakKeyword,
             .trueKeyword, .falseKeyword:
            return true
        default:
            return false
        }
    }

    /// Returns true if this token type represents a literal.
    public var isLiteral: Bool {
        switch self {
        case .integerLiteral, .realLiteral, .stringLiteral, .characterLiteral:
            return true
        default:
            return false
        }
    }

    /// Returns true if this token type represents an operator.
    public var isOperator: Bool {
        switch self {
        case .plus, .minus, .multiply, .divide, .modulo, .assign,
             .equal, .notEqual, .greater, .greaterEqual, .less, .lessEqual:
            return true
        default:
            return false
        }
    }
}
