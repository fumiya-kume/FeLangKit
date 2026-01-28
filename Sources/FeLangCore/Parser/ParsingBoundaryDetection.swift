import Foundation

/// Shared utilities for detecting parsing boundaries and validating expression/statement structure.
/// This consolidates boundary detection logic used across different parser implementations.
public enum ParsingBoundaryDetection {

    // MARK: - Statement Boundary Detection

    /// Determines if a token type indicates the end of an expression (statement boundary)
    /// This is used to identify where expressions end and new statements begin
    public static func isStatementTerminator(_ tokenType: TokenType) -> Bool {
        switch tokenType {
        // Basic terminators
        case .newline, .eof:
            return true

        // Control flow keywords that end expressions and start new statement blocks
        case .thenKeyword,      // IF condition ends, THEN block begins
             .elseKeyword,      // Previous block ends, ELSE block begins
             .elifKeyword,      // Previous block ends, ELIF condition begins
             .elseifKeyword,    // Previous block ends, ELSEIF condition begins
             .doKeyword:        // WHILE/FOR condition ends, DO block begins
            return true

        // Block termination keywords that end expressions and close statement blocks
        case .endifKeyword,     // IF statement block ends
             .endwhileKeyword,  // WHILE statement block ends
             .endforKeyword,    // FOR statement block ends
             .endfunctionKeyword,   // FUNCTION declaration block ends
             .endprocedureKeyword,  // PROCEDURE declaration block ends
             .endclassKeyword:      // CLASS declaration block ends
            return true

        // FOR loop specific keywords that separate expression components
        case .toKeyword,        // Separates start and end expressions: FOR i ← 1 TO 10
             .stepKeyword,      // Separates end and step expressions: TO 10 STEP 2
             .inKeyword:        // Separates variable and iterable: FOR item IN array
            return true

        // General expression separators
        case .comma:            // Separates function arguments, parameter lists
            return true

        default:
            return false
        }
    }

    /// Checks if a token type indicates expression continuation (operator, opening bracket, comma, etc.)
    /// Used to distinguish between function calls as new statements vs function calls within expressions
    private static func isExpressionContinuationToken(_ tokenType: TokenType) -> Bool {
        switch tokenType {
        // Binary operators
        case .plus, .minus, .multiply, .divide, .modulo, .modKeyword:
            return true
        // Comparison operators
        case .equal, .notEqual, .less, .greater, .lessEqual, .greaterEqual:
            return true
        // Logical operators
        case .andKeyword, .orKeyword:
            return true
        // Opening brackets, comma, and dot (function arguments, array access, field access)
        case .leftParen, .leftBracket, .comma, .dot:
            return true
        // Assignment operator
        case .assign:
            return true
        default:
            return false
        }
    }

    /// Checks if a token sequence indicates the start of a new statement
    /// This helps detect statement boundaries when newlines are filtered out
    public static func isStartOfNewStatement(_ tokens: [Token], at index: Int) -> Bool {
        guard index < tokens.count else { return false }

        let token = tokens[index]

        // Check for identifier-based patterns (assignment, function call, array element assignment)
        if token.type == .identifier && index + 1 < tokens.count {
            return isIdentifierStartingNewStatement(tokens, at: index)
        }

        // Check for statement-starting keywords
        return isStatementStartingKeyword(token.type)
    }

    /// Checks if an identifier at the given position starts a new statement
    /// Detects assignment, function call, and array element assignment patterns
    private static func isIdentifierStartingNewStatement(_ tokens: [Token], at index: Int) -> Bool {
        let nextToken = tokens[index + 1]
        if nextToken.type == .assign {
            return true
        }
        // Function call pattern: identifier(
        // But NOT if preceded by an operator (expression continuation)
        if nextToken.type == .leftParen {
            if index > 0 && isExpressionContinuationToken(tokens[index - 1].type) {
                return false
            }
            return true
        }
        // Array element assignment pattern: identifier[...]←
        if nextToken.type == .leftBracket {
            return isArrayAssignmentPattern(tokens, at: index)
        }
        return false
    }

    /// Checks if an identifier followed by brackets forms an array assignment pattern
    private static func isArrayAssignmentPattern(_ tokens: [Token], at index: Int) -> Bool {
        var offset = 2
        var bracketCount = 1
        while bracketCount > 0, index + offset < tokens.count {
            let scanToken = tokens[index + offset]
            if scanToken.type == .leftBracket { bracketCount += 1 } else if scanToken.type == .rightBracket { bracketCount -= 1 }
            offset += 1
        }
        guard index + offset < tokens.count else { return false }
        let afterBracket = tokens[index + offset]
        if afterBracket.type == .assign {
            return true
        }
        if isExpressionContinuationToken(afterBracket.type) {
            return false
        }
        return false
    }

    /// Checks if a token type is a keyword that starts a new statement
    private static func isStatementStartingKeyword(_ tokenType: TokenType) -> Bool {
        switch tokenType {
        case .ifKeyword, .whileKeyword, .doKeyword, .forKeyword,
             .variableKeyword, .constantKeyword, .globalKeyword,
             .functionKeyword, .procedureKeyword, .classKeyword,
             .returnKeyword, .breakKeyword, .continueKeyword:
            return true
        default:
            return false
        }
    }

    // MARK: - Expression Boundary Detection

    /// Finds the end index of an expression in a token array
    /// Uses balanced parentheses/brackets tracking to determine expression boundaries
    public static func findExpressionBoundary(in tokens: [Token], startingAt startIndex: Int) -> Int {
        guard startIndex < tokens.count else { return startIndex }

        var endIndex = startIndex
        var parenDepth = 0
        var bracketDepth = 0
        var braceDepth = 0

        // Scan forward to find expression boundary
        var scanIndex = startIndex
        while scanIndex < tokens.count {
            let token = tokens[scanIndex]
            let tokenType = token.type

            // Handle EOF
            if tokenType == .eof {
                endIndex = scanIndex
                break
            }

            // Track nested structures
            updateDepthCounters(for: tokenType,
                              parenDepth: &parenDepth,
                              bracketDepth: &bracketDepth,
                              braceDepth: &braceDepth)

            // Check for early termination due to unmatched closing brackets
            if parenDepth < 0 || bracketDepth < 0 || braceDepth < 0 {
                endIndex = scanIndex
                break
            }

            // Stop at statement terminators only when we're not inside nested structures
            if parenDepth == 0 && bracketDepth == 0 && braceDepth == 0 &&
               isStatementTerminator(tokenType) {
                endIndex = scanIndex
                break
            }

            // Also stop if we detect the start of a new statement
            if parenDepth == 0 && bracketDepth == 0 && braceDepth == 0 &&
               scanIndex > startIndex && isStartOfNewStatement(tokens, at: scanIndex) {
                endIndex = scanIndex
                break
            }

            scanIndex += 1
        }

        return endIndex
    }

    /// Updates depth counters for nested structures
    private static func updateDepthCounters(
        for tokenType: TokenType,
        parenDepth: inout Int,
        bracketDepth: inout Int,
        braceDepth: inout Int
    ) {
        switch tokenType {
        case .leftParen:
            parenDepth += 1
        case .rightParen:
            parenDepth -= 1
        case .leftBracket:
            bracketDepth += 1
        case .rightBracket:
            bracketDepth -= 1
        case .leftBrace:
            braceDepth += 1
        case .rightBrace:
            braceDepth -= 1
        default:
            break
        }
    }

    // MARK: - Expression Validation

    /// Validates that a token sequence represents a balanced expression
    /// Checks for proper nesting of parentheses, brackets, and braces
    public static func isValidBalancedExpression(_ tokens: ArraySlice<Token>) -> Bool {
        var parenDepth = 0
        var bracketDepth = 0
        var braceDepth = 0

        for token in tokens {
            updateDepthCounters(for: token.type,
                              parenDepth: &parenDepth,
                              bracketDepth: &bracketDepth,
                              braceDepth: &braceDepth)

            // Check for negative depth (closing without opening)
            if parenDepth < 0 || bracketDepth < 0 || braceDepth < 0 {
                return false
            }
        }

        // All depths should be zero for a balanced expression
        return parenDepth == 0 && bracketDepth == 0 && braceDepth == 0
    }

    /// Validates that parentheses are properly balanced in a token sequence
    /// Specific check for parentheses only (useful for function calls)
    public static func hasBalancedParentheses(_ tokens: ArraySlice<Token>) -> Bool {
        var depth = 0

        for token in tokens {
            switch token.type {
            case .leftParen:
                depth += 1
            case .rightParen:
                depth -= 1
                if depth < 0 { return false }
            default:
                break
            }
        }

        return depth == 0
    }

    /// Validates that brackets are properly balanced in a token sequence
    /// Specific check for array access and subscripting
    public static func hasBalancedBrackets(_ tokens: ArraySlice<Token>) -> Bool {
        var depth = 0

        for token in tokens {
            switch token.type {
            case .leftBracket:
                depth += 1
            case .rightBracket:
                depth -= 1
                if depth < 0 { return false }
            default:
                break
            }
        }

        return depth == 0
    }

    // MARK: - Block Structure Detection

    /// Determines if a token marks the start of a block structure
    /// Used for detecting nested control flow structures
    /// Note: doKeyword is not included because do-while loops have a different termination pattern
    /// (they end with 'while (condition)' instead of an 'enddo' keyword)
    public static func isBlockStartToken(_ tokenType: TokenType) -> Bool {
        switch tokenType {
        case .ifKeyword, .whileKeyword, .forKeyword, .functionKeyword, .procedureKeyword, .classKeyword:
            return true
        default:
            return false
        }
    }

    /// Determines if a token marks the end of a block structure
    /// Used for matching block start/end pairs
    public static func isBlockEndToken(_ tokenType: TokenType) -> Bool {
        switch tokenType {
        case .endifKeyword, .endwhileKeyword, .endforKeyword, .endfunctionKeyword, .endprocedureKeyword, .endclassKeyword:
            return true
        default:
            return false
        }
    }

    /// Finds the matching end token for a block start token
    /// Supports nested block structures with proper depth tracking
    public static func findMatchingBlockEnd(in tokens: [Token], startingAt startIndex: Int) -> Int? {
        guard startIndex < tokens.count else { return nil }

        let startToken = tokens[startIndex]
        guard isBlockStartToken(startToken.type) else { return nil }

        var depth = 1
        var index = startIndex + 1

        while index < tokens.count && depth > 0 {
            let token = tokens[index]

            if isBlockStartToken(token.type) {
                depth += 1
            } else if isBlockEndToken(token.type) {
                depth -= 1

                if depth == 0 {
                    // Verify this is the correct end token type
                    if isMatchingEndToken(startToken.type, token.type) {
                        return index
                    } else {
                        return nil // Mismatched block end
                    }
                }
            }

            index += 1
        }

        return nil // No matching end found
    }

    /// Checks if start and end tokens form a valid block pair
    private static func isMatchingEndToken(_ startType: TokenType, _ endType: TokenType) -> Bool {
        switch (startType, endType) {
        case (.ifKeyword, .endifKeyword),
             (.whileKeyword, .endwhileKeyword),
             (.forKeyword, .endforKeyword),
             (.functionKeyword, .endfunctionKeyword),
             (.procedureKeyword, .endprocedureKeyword),
             (.classKeyword, .endclassKeyword):
            return true
        default:
            return false
        }
    }

    // MARK: - Context Analysis

    /// Analyzes the parsing context at a given position
    /// Provides information about nesting levels and structure
    public static func analyzeParsingContext(in tokens: [Token], at index: Int) -> ParsingContext {
        var parenDepth = 0
        var bracketDepth = 0
        var braceDepth = 0
        var blockDepth = 0
        var lastStatement: TokenType?

        // Scan from beginning to current position
        for tokenIndex in 0..<min(index, tokens.count) {
            let token = tokens[tokenIndex]

            updateDepthCounters(for: token.type,
                              parenDepth: &parenDepth,
                              bracketDepth: &bracketDepth,
                              braceDepth: &braceDepth)

            if isBlockStartToken(token.type) {
                blockDepth += 1
            } else if isBlockEndToken(token.type) {
                blockDepth = max(0, blockDepth - 1)
            }

            if isStartOfNewStatement([token], at: 0) {
                lastStatement = token.type
            }
        }

        return ParsingContext(
            parenthesesDepth: parenDepth,
            bracketDepth: bracketDepth,
            braceDepth: braceDepth,
            blockDepth: blockDepth,
            lastStatementType: lastStatement,
            canStartNewStatement: parenDepth == 0 && bracketDepth == 0 && braceDepth == 0
        )
    }
}

// MARK: - Supporting Types

/// Information about the parsing context at a specific position
public struct ParsingContext {
    public let parenthesesDepth: Int
    public let bracketDepth: Int
    public let braceDepth: Int
    public let blockDepth: Int
    public let lastStatementType: TokenType?
    public let canStartNewStatement: Bool

    /// Whether we're currently inside any nested structure
    public var isInsideNestedStructure: Bool {
        return parenthesesDepth > 0 || bracketDepth > 0 || braceDepth > 0
    }

    /// Whether we're at the top level (not nested in any structure)
    public var isAtTopLevel: Bool {
        return blockDepth == 0 && !isInsideNestedStructure
    }
}
