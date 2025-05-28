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
             .doKeyword:        // WHILE/FOR condition ends, DO block begins
            return true

        // Block termination keywords that end expressions and close statement blocks
        case .endifKeyword,     // IF statement block ends
             .endwhileKeyword,  // WHILE statement block ends
             .endforKeyword,    // FOR statement block ends
             .endfunctionKeyword,   // FUNCTION declaration block ends
             .endprocedureKeyword:  // PROCEDURE declaration block ends
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

    /// Checks if a token sequence indicates the start of a new statement
    /// This helps detect statement boundaries when newlines are filtered out
    public static func isStartOfNewStatement(_ tokens: [Token], at index: Int) -> Bool {
        guard index < tokens.count else { return false }

        let token = tokens[index]

        // Check for assignment pattern: identifier ←
        if token.type == .identifier && index + 1 < tokens.count {
            let nextToken = tokens[index + 1]
            if nextToken.type == .assign {
                return true
            }
        }

        // Check for statement-starting keywords
        switch token.type {
        // Control flow statements
        case .ifKeyword,        // IF-THEN-ELSE conditional statements
             .whileKeyword,     // WHILE-DO loop statements
             .forKeyword:       // FOR loop statements (range or forEach)
            return true

        // Declaration statements
        case .variableKeyword,  // Variable declarations: 変数 name: type ← value
             .constantKeyword:  // Constant declarations: 定数 name: type ← value
            return true

        // Function/procedure declarations
        case .functionKeyword,  // FUNCTION declarations with return values
             .procedureKeyword: // PROCEDURE declarations without return values
            return true

        // Flow control statements
        case .returnKeyword,    // RETURN statements (with or without values)
             .breakKeyword:     // BREAK statements for loop termination
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
    public static func isBlockStartToken(_ tokenType: TokenType) -> Bool {
        switch tokenType {
        case .ifKeyword, .whileKeyword, .forKeyword, .functionKeyword, .procedureKeyword:
            return true
        default:
            return false
        }
    }

    /// Determines if a token marks the end of a block structure
    /// Used for matching block start/end pairs
    public static func isBlockEndToken(_ tokenType: TokenType) -> Bool {
        switch tokenType {
        case .endifKeyword, .endwhileKeyword, .endforKeyword, .endfunctionKeyword, .endprocedureKeyword:
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
             (.procedureKeyword, .endprocedureKeyword):
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
