import Foundation
@testable import FeLangCore

/// Provides consistent error message formatting for ParseError testing.
/// This formatter ensures that error messages are standardized across the golden file test suite
/// and provides clear, actionable feedback for parsing failures.
public struct ErrorFormatter {
    
    // MARK: - Public Interface
    
    /// Formats any parsing-related error into a standardized string representation.
    /// This method handles both ExpressionParser errors and StatementParser errors,
    /// ensuring consistent formatting across all parse error scenarios.
    ///
    /// - Parameter error: The error to format (ParsingError or StatementParsingError)
    /// - Returns: A formatted error string suitable for golden file comparison
    public static func format(_ error: Error) -> String {
        switch error {
        case let parsingError as ParsingError:
            return formatParsingError(parsingError)
        case let statementError as StatementParsingError:
            return formatStatementParsingError(statementError)
        default:
            return formatGenericError(error)
        }
    }
    
    /// Formats a parsing error with detailed context information.
    /// Includes error type, position information, and expected vs actual tokens.
    ///
    /// - Parameters:
    ///   - error: The parsing error to format
    ///   - input: Optional input source for additional context
    /// - Returns: A comprehensive error message with source context
    public static func formatWithContext(_ error: Error, input: String? = nil) -> String {
        let basicFormat = format(error)
        
        guard let input = input else {
            return basicFormat
        }
        
        // Add source context if position information is available
        if let position = extractPosition(from: error) {
            let contextLines = extractSourceContext(input: input, position: position)
            return basicFormat + "\n" + contextLines
        }
        
        return basicFormat
    }
    
    // MARK: - Expression Parser Error Formatting
    
    private static func formatParsingError(_ error: ParsingError) -> String {
        switch error {
        case .unexpectedEndOfInput:
            return "ParseError: Unexpected end of input\n" +
                   "  Expected: expression or statement"
            
        case .unexpectedToken(let token, let expected):
            return "ParseError: Unexpected token '\(token.lexeme)'\n" +
                   "  at \(formatPosition(token.position))\n" +
                   "  Expected: \(expected)"
            
        case .expectedPrimaryExpression(let token):
            return "ParseError: Expected primary expression\n" +
                   "  at \(formatPosition(token.position))\n" +
                   "  Found: '\(token.lexeme)'"
            
        case .expectedIdentifier:
            return "ParseError: Expected identifier\n" +
                   "  Found: invalid or missing identifier"
        }
    }
    
    // MARK: - Statement Parser Error Formatting
    
    private static func formatStatementParsingError(_ error: StatementParsingError) -> String {
        switch error {
        case .unexpectedEndOfInput:
            return "StatementParseError: Unexpected end of input\n" +
                   "  Expected: complete statement"
            
        case .unexpectedToken(let token, let expected):
            return "StatementParseError: Unexpected token '\(token.lexeme)'\n" +
                   "  at \(formatPosition(token.position))\n" +
                   "  Expected: \(expected)"
            
        case .expectedTokens(let expectedTokens):
            let tokenList = expectedTokens.map { "\($0)" }.joined(separator: ", ")
            return "StatementParseError: Expected one of: \(tokenList)"
            
        case .expectedIdentifier:
            return "StatementParseError: Expected identifier\n" +
                   "  Found: invalid or missing identifier"
            
        case .expectedDataType:
            return "StatementParseError: Expected data type\n" +
                   "  Expected: integer, real, string, boolean, array, or record type"
            
        case .expectedToken(let expected):
            return "StatementParseError: Expected token '\(expected)'\n" +
                   "  Token missing or incorrect"
            
        case .expectedPrimaryExpression(let token):
            return "StatementParseError: Expected primary expression\n" +
                   "  at \(formatPosition(token.position))\n" +
                   "  Found: '\(token.lexeme)'"
            
        case .inputTooLarge:
            return "StatementParseError: Input too large for safe processing\n" +
                   "  Maximum input size exceeded (100,000 tokens)"
            
        case .nestingTooDeep:
            return "StatementParseError: Nesting depth too deep\n" +
                   "  Maximum nesting depth exceeded (100 levels)"
            
        case .identifierTooLong(let name):
            let truncated = String(name.prefix(20))
            return "StatementParseError: Identifier too long\n" +
                   "  Identifier: '\(truncated)...'\n" +
                   "  Maximum length exceeded (255 characters)"
            
        case .expressionTooComplex:
            return "StatementParseError: Expression too complex\n" +
                   "  Expression complexity exceeds safe evaluation limits"
            
        case .invalidArrayDimension:
            return "StatementParseError: Invalid array dimension\n" +
                   "  Array dimension specification is malformed"
            
        case .invalidFunctionArity(let function, let expected, let actual):
            return "StatementParseError: Invalid function arity\n" +
                   "  Function: '\(function)'\n" +
                   "  Expected: \(expected) arguments\n" +
                   "  Actual: \(actual) arguments"
            
        case .undeclaredVariable(let name):
            return "StatementParseError: Undeclared variable\n" +
                   "  Variable: '\(name)'\n" +
                   "  Variable must be declared before use"
            
        case .cyclicDependency(let variables):
            let varList = variables.joined(separator: " -> ")
            return "StatementParseError: Cyclic dependency detected\n" +
                   "  Dependency chain: \(varList)"
        }
    }
    
    // MARK: - Generic Error Formatting
    
    private static func formatGenericError(_ error: Error) -> String {
        return "UnknownParseError: \(error.localizedDescription)"
    }
    
    // MARK: - Position Formatting
    
    private static func formatPosition(_ position: SourcePosition) -> String {
        return "line \(position.line), column \(position.column)"
    }
    
    // MARK: - Context Extraction
    
    private static func extractPosition(from error: Error) -> SourcePosition? {
        switch error {
        case let parsingError as ParsingError:
            switch parsingError {
            case .unexpectedToken(let token, _),
                 .expectedPrimaryExpression(let token):
                return token.position
            default:
                return nil
            }
        case let statementError as StatementParsingError:
            switch statementError {
            case .unexpectedToken(let token, _),
                 .expectedPrimaryExpression(let token):
                return token.position
            default:
                return nil
            }
        default:
            return nil
        }
    }
    
    private static func extractSourceContext(input: String, position: SourcePosition) -> String {
        let lines = input.components(separatedBy: .newlines)
        
        guard position.line > 0 && position.line <= lines.count else {
            return "  (Source context unavailable)"
        }
        
        let currentLine = lines[position.line - 1]
        let lineNumber = position.line
        
        var context = "  Source context:\n"
        context += "  \(lineNumber): \(currentLine)\n"
        
        // Add pointer to the error position
        let spaces = String(repeating: " ", count: position.column - 1)
        let lineNumberPadding = String(repeating: " ", count: "\(lineNumber): ".count)
        context += "  \(lineNumberPadding)\(spaces)^"
        
        return context
    }
}
