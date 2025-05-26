import Foundation

/// A unified parser for FE pseudo-language that provides a clean interface
/// for parsing source code into strictly typed AST nodes.
/// 
/// This parser integrates the existing StatementParser and ExpressionParser
/// with the ParsingTokenizer to provide a complete parsing solution.
/// It also supports optional semantic analysis for type checking and validation.
public struct Parser {
    private let tokenizer: ParsingTokenizer
    private let statementParser: StatementParser
    private let expressionParser: ExpressionParser
    
    /// Configuration for parsing and semantic analysis
    public struct Options {
        /// Whether to perform semantic analysis after parsing
        public var performSemanticAnalysis: Bool = false
        
        /// Options for semantic analysis when enabled
        public var semanticAnalysisOptions: SemanticAnalyzer.AnalysisOptions = SemanticAnalyzer.AnalysisOptions()
        
        public init() {}
    }
    
    private let options: Options

    public init(options: Options = Options()) {
        self.tokenizer = ParsingTokenizer()
        self.statementParser = StatementParser()
        self.expressionParser = ExpressionParser()
        self.options = options
    }

    /// Parses FE pseudo-language source code into an array of statements.
    ///
    /// - Parameter sourceCode: The source code string to parse
    /// - Returns: Array of parsed Statement objects representing the AST
    /// - Throws: ParseError if parsing fails due to lexical or syntax errors
    ///
    /// Example:
    /// ```swift
    /// let parser = Parser()
    /// let ast = try parser.parse("variable x: integer ← 42")
    /// ```
    public func parse(_ sourceCode: String) throws -> [Statement] {
        do {
            // Tokenize the source code
            let tokens = try tokenizer.tokenize(sourceCode)

            // Parse tokens into statements
            let statements = try statementParser.parseStatements(from: tokens)

            return statements

        } catch let error as ParsingError {
            throw ParseError.from(error)
        } catch let error as StatementParsingError {
            throw ParseError.from(error)
        } catch {
            // Handle any other errors
            throw ParseError(
                message: "Unexpected parsing error: \(error.localizedDescription)",
                line: 0,
                column: 0
            )
        }
    }

    /// Parses a single expression from source code.
    ///
    /// - Parameter sourceCode: The source code string containing an expression
    /// - Returns: Parsed Expression object
    /// - Throws: ParseError if parsing fails
    ///
    /// Example:
    /// ```swift
    /// let parser = Parser()
    /// let expr = try parser.parseExpression("x + y * 2")
    /// ```
    public func parseExpression(_ sourceCode: String) throws -> Expression {
        do {
            // Tokenize the source code
            let tokens = try tokenizer.tokenize(sourceCode)

            // Parse tokens into expression
            let expression = try expressionParser.parseExpression(from: tokens)

            return expression

        } catch let error as ParsingError {
            throw ParseError.from(error)
        } catch {
            // Handle any other errors
            throw ParseError(
                message: "Unexpected expression parsing error: \(error.localizedDescription)",
                line: 0,
                column: 0
            )
        }
    }

    /// Validates that the given source code can be parsed without errors.
    ///
    /// - Parameter sourceCode: The source code to validate
    /// - Returns: true if the code is syntactically valid, false otherwise
    public func validate(_ sourceCode: String) -> Bool {
        do {
            _ = try parse(sourceCode)
            return true
        } catch {
            return false
        }
    }

    /// Parses source code and collects all parsing errors with their positions.
    ///
    /// - Parameter sourceCode: The source code to parse
    /// - Returns: Array of ParseError objects with detailed position information
    public func collectErrors(_ sourceCode: String) -> [ParseError] {
        var errors: [ParseError] = []

        do {
            _ = try parse(sourceCode)
        } catch let parseError as ParseError {
            errors.append(parseError)
        } catch {
            errors.append(ParseError(
                message: "Unknown parsing error: \(error.localizedDescription)",
                line: 0,
                column: 0
            ))
        }

        return errors
    }
    
    /// Represents the result of parsing with optional semantic analysis
    public struct ParseResult {
        /// The parsed AST statements
        public let statements: [Statement]
        
        /// Semantic analysis result (only present if semantic analysis was performed)
        public let semanticAnalysis: SemanticAnalysisResult?
        
        /// Whether the parsing was successful (syntax and optionally semantics)
        public var isSuccessful: Bool {
            return semanticAnalysis?.isSuccessful ?? true
        }
        
        /// All errors from parsing and semantic analysis
        public var allErrors: [Error] {
            var errors: [Error] = []
            if let semanticResult = semanticAnalysis {
                errors.append(contentsOf: semanticResult.errors)
            }
            return errors
        }
        
        public init(statements: [Statement], semanticAnalysis: SemanticAnalysisResult? = nil) {
            self.statements = statements
            self.semanticAnalysis = semanticAnalysis
        }
    }
    
    /// Parses source code with optional semantic analysis.
    ///
    /// - Parameter sourceCode: The source code string to parse
    /// - Returns: ParseResult containing AST and optional semantic analysis
    /// - Throws: ParseError if syntax parsing fails
    ///
    /// Example:
    /// ```swift
    /// var options = Parser.Options()
    /// options.performSemanticAnalysis = true
    /// let parser = Parser(options: options)
    /// let result = try parser.parseWithAnalysis("variable x: integer ← 42")
    /// if !result.isSuccessful {
    ///     print("Semantic errors: \(result.semanticAnalysis?.errors ?? [])")
    /// }
    /// ```
    public func parseWithAnalysis(_ sourceCode: String) throws -> ParseResult {
        // First perform syntax parsing
        let statements = try parse(sourceCode)
        
        // Perform semantic analysis if enabled
        var semanticResult: SemanticAnalysisResult? = nil
        if options.performSemanticAnalysis {
            let analyzer = SemanticAnalyzer(options: options.semanticAnalysisOptions)
            semanticResult = analyzer.analyze(statements: statements)
        }
        
        return ParseResult(statements: statements, semanticAnalysis: semanticResult)
    }
    
    /// Parses and validates source code with both syntax and semantic checking.
    ///
    /// - Parameter sourceCode: The source code to validate
    /// - Returns: true if the code is both syntactically and semantically valid
    public func validateWithSemantics(_ sourceCode: String) -> Bool {
        do {
            let result = try parseWithAnalysis(sourceCode)
            return result.isSuccessful
        } catch {
            return false
        }
    }
    
    /// Collects all parsing and semantic errors from source code.
    ///
    /// - Parameter sourceCode: The source code to analyze
    /// - Returns: Array of all errors found during parsing and semantic analysis
    public func collectAllErrors(_ sourceCode: String) -> [Error] {
        var allErrors: [Error] = []
        
        do {
            let result = try parseWithAnalysis(sourceCode)
            allErrors.append(contentsOf: result.allErrors)
        } catch let parseError {
            allErrors.append(parseError)
        }
        
        return allErrors
    }
}

// MARK: - Parser Configuration

extension Parser {
    /// Configuration options for the parser
    public struct Configuration {
        /// Maximum allowed nesting depth for control structures
        public var maxNestingDepth: Int = 100

        /// Maximum number of tokens to process (security limit)
        public var maxTokenCount: Int = 100_000

        /// Whether to collect detailed error context
        public var collectErrorContext: Bool = true

        public init() {}
    }

    /// Creates a parser with custom configuration
    public init(configuration: Configuration) {
        // For now, use default parsers
        // Future enhancement: pass configuration to underlying parsers
        self.tokenizer = ParsingTokenizer()
        self.statementParser = StatementParser()
        self.expressionParser = ExpressionParser()
        self.options = Options()
    }
}

// MARK: - Convenience Methods

extension Parser {
    /// Parses a single statement from source code.
    ///
    /// - Parameter sourceCode: Source code containing exactly one statement
    /// - Returns: The parsed Statement
    /// - Throws: ParseError if parsing fails or if there are multiple statements
    public func parseStatement(_ sourceCode: String) throws -> Statement {
        let statements = try parse(sourceCode)

        guard statements.count == 1 else {
            throw ParseError(
                message: "Expected exactly one statement, found \(statements.count)",
                line: 0,
                column: 0
            )
        }

        return statements[0]
    }

    /// Parses and validates a code fragment for a specific grammar rule.
    ///
    /// - Parameters:
    ///   - sourceCode: The source code fragment
    ///   - rule: The expected grammar rule (for validation)
    /// - Returns: The parsed statements
    /// - Throws: ParseError if parsing fails or doesn't match the expected rule
    public func parseFragment(_ sourceCode: String, expectedRule: GrammarRule) throws -> [Statement] {
        let statements = try parse(sourceCode)

        // Validate that the parsed statements match the expected grammar rule
        try validateGrammarRule(statements, expectedRule: expectedRule)

        return statements
    }

    /// Grammar rules for validation
    public enum GrammarRule {
        case variableDeclaration
        case constantDeclaration
        case ifStatement
        case whileStatement
        case forStatement
        case functionDeclaration
        case procedureDeclaration
        case assignment
        case expressionStatement
        case returnStatement
        case breakStatement
    }

    /// Validates that statements conform to the expected grammar rule
    private func validateGrammarRule(_ statements: [Statement], expectedRule: GrammarRule) throws {
        guard statements.count == 1 else {
            throw ParseError(
                message: "Grammar rule validation requires exactly one statement",
                line: 0,
                column: 0
            )
        }

        let statement = statements[0]
        let isValid: Bool

        switch expectedRule {
        case .variableDeclaration:
            isValid = statement.isVariableDeclaration
        case .constantDeclaration:
            isValid = statement.isConstantDeclaration
        case .ifStatement:
            isValid = statement.isIfStatement
        case .whileStatement:
            isValid = statement.isWhileStatement
        case .forStatement:
            isValid = statement.isForStatement
        case .functionDeclaration:
            isValid = statement.isFunctionDeclaration
        case .procedureDeclaration:
            isValid = statement.isProcedureDeclaration
        case .assignment:
            isValid = statement.isAssignment
        case .expressionStatement:
            isValid = statement.isExpressionStatement
        case .returnStatement:
            isValid = statement.isReturnStatement
        case .breakStatement:
            isValid = statement.isBreakStatement
        }

        if !isValid {
            throw ParseError(
                message: "Statement does not match expected grammar rule: \(expectedRule)",
                line: 0,
                column: 0
            )
        }
    }
}

// MARK: - Statement Type Checking Extensions

private extension Statement {
    var isVariableDeclaration: Bool {
        if case .variableDeclaration = self { return true }
        return false
    }

    var isConstantDeclaration: Bool {
        if case .constantDeclaration = self { return true }
        return false
    }

    var isIfStatement: Bool {
        if case .ifStatement = self { return true }
        return false
    }

    var isWhileStatement: Bool {
        if case .whileStatement = self { return true }
        return false
    }

    var isForStatement: Bool {
        if case .forStatement = self { return true }
        return false
    }

    var isFunctionDeclaration: Bool {
        if case .functionDeclaration = self { return true }
        return false
    }

    var isProcedureDeclaration: Bool {
        if case .procedureDeclaration = self { return true }
        return false
    }

    var isAssignment: Bool {
        if case .assignment = self { return true }
        return false
    }

    var isExpressionStatement: Bool {
        if case .expressionStatement = self { return true }
        return false
    }

    var isReturnStatement: Bool {
        if case .returnStatement = self { return true }
        return false
    }

    var isBreakStatement: Bool {
        if case .breakStatement = self { return true }
        return false
    }
}
