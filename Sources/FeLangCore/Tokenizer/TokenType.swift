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
    case thenKeyword = "then"
    case elseKeyword = "else"
    case elifKeyword = "elif"
    case endifKeyword = "endif"
    case whileKeyword = "while"
    case doKeyword = "do"
    case endwhileKeyword = "endwhile"
    case forKeyword = "for"
    case toKeyword = "to"
    case stepKeyword = "step"
    case inKeyword = "in"
    case endforKeyword = "endfor"
    case functionKeyword = "function"
    case endfunctionKeyword = "endfunction"
    case procedureKeyword = "procedure"
    case endprocedureKeyword = "endprocedure"
    case returnKeyword = "return"
    case breakKeyword = "break"

    /// Logical keywords
    case andKeyword = "and"
    case orKeyword = "or"
    case notKeyword = "not"

    /// Boolean literals
    case trueKeyword = "true"
    case falseKeyword = "false"

    /// Declaration keywords
    case variableKeyword = "変数"
    case constantKeyword = "定数"

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
}

extension TokenType {
    /// Returns true if this token type represents a keyword.
    public var isKeyword: Bool {
        switch self {
        case .integerType, .realType, .characterType, .stringType, .booleanType,
             .recordType, .arrayType, .ifKeyword, .thenKeyword, .elseKeyword, .elifKeyword, .endifKeyword,
             .whileKeyword, .doKeyword, .endwhileKeyword, .forKeyword, .toKeyword, .stepKeyword, .inKeyword, .endforKeyword,
             .functionKeyword, .endfunctionKeyword, .procedureKeyword, .endprocedureKeyword,
             .andKeyword, .orKeyword, .notKeyword, .returnKeyword, .breakKeyword,
             .trueKeyword, .falseKeyword, .variableKeyword, .constantKeyword:
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
