import Foundation
import Parsing

/// A bidirectional parser-printer for FE pseudo-language that supports round-trip validation.
/// This enables parsing source code to AST and printing AST back to canonical source code.
public struct ParserPrinter {
    private let parser: Parser
    private let prettyPrinter: PrettyPrinter
    private let validateRoundTrips: Bool

    public init(configuration: PrettyPrinter.Configuration = PrettyPrinter.Configuration(), validateRoundTrips: Bool = true) {
        self.parser = Parser()
        self.prettyPrinter = PrettyPrinter(configuration: configuration)
        self.validateRoundTrips = validateRoundTrips
    }

    /// Performs round-trip validation: source → AST → source
    /// This ensures that the parser and printer are consistent.
    ///
    /// - Parameter sourceCode: Original FE pseudo-language source code
    /// - Returns: Tuple containing the parsed AST and the regenerated source code
    /// - Throws: ParseError if parsing fails or RoundTripError if validation fails
    public func roundTrip(_ sourceCode: String) throws -> (ast: [Statement], regenerated: String) {
        // Parse source to AST
        let ast = try parser.parse(sourceCode)

        // Print AST back to source
        let regenerated = prettyPrinter.print(ast)

        // Validate round-trip consistency if enabled
        if validateRoundTrips {
            try validateRoundTrip(original: sourceCode, regenerated: regenerated, ast: ast)
        }

        return (ast: ast, regenerated: regenerated)
    }

    /// Validates that round-trip parsing produces equivalent results
    private func validateRoundTrip(original: String, regenerated: String, ast: [Statement]) throws {
        do {
            // Parse the regenerated code
            let reparsedAST = try parser.parse(regenerated)

            // Compare ASTs for structural equality
            guard ast == reparsedAST else {
                throw RoundTripError.astMismatch(
                    original: ast,
                    reparsed: reparsedAST,
                    originalSource: original,
                    regeneratedSource: regenerated
                )
            }

            // Optionally validate semantic equivalence
            try validateSemanticEquivalence(original: original, regenerated: regenerated)

        } catch let parseError as ParseError {
            throw RoundTripError.reparseFailure(
                regeneratedSource: regenerated,
                originalSource: original,
                parseError: parseError
            )
        }
    }

    /// Validates semantic equivalence between original and regenerated code
    private func validateSemanticEquivalence(original: String, regenerated: String) throws {
        // Normalize whitespace and compare logical structure
        let normalizedOriginal = normalizeForComparison(original)
        let normalizedRegenerated = normalizeForComparison(regenerated)

        // Allow for formatting differences but ensure logical equivalence
        if !areLogicallyEquivalent(normalizedOriginal, normalizedRegenerated) {
            throw RoundTripError.semanticMismatch(
                original: original,
                regenerated: regenerated
            )
        }
    }

    /// Normalizes source code for comparison by standardizing whitespace and formatting
    private func normalizeForComparison(_ source: String) -> String {
        return source
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            // Preserve case sensitivity by not lowercasing the source
    }

    /// Checks if two normalized source strings are logically equivalent
    private func areLogicallyEquivalent(_ lhs: String, _ rhs: String) -> Bool {
        // For now, simple string comparison after normalization
        // This could be enhanced with more sophisticated semantic analysis
        return lhs == rhs
    }
}

// MARK: - Round Trip Errors

/// Errors that can occur during round-trip validation
public enum RoundTripError: Error, CustomStringConvertible {
    case astMismatch(original: [Statement], reparsed: [Statement], originalSource: String, regeneratedSource: String)
    case reparseFailure(regeneratedSource: String, originalSource: String, parseError: ParseError)
    case semanticMismatch(original: String, regenerated: String)

    public var description: String {
        switch self {
        case .astMismatch(let original, let reparsed, let originalSource, let regeneratedSource):
            return """
            Round-trip validation failed: AST mismatch
            Original AST: \(original.count) statements
            Reparsed AST: \(reparsed.count) statements
            Original source:
            \(originalSource)
            Regenerated source:
            \(regeneratedSource)
            """

        case .reparseFailure(let regeneratedSource, let originalSource, let parseError):
            return """
            Round-trip validation failed: Unable to reparse generated code
            Parse error: \(parseError)
            Original source:
            \(originalSource)
            Generated source that failed to parse:
            \(regeneratedSource)
            """

        case .semanticMismatch(let original, let regenerated):
            return """
            Round-trip validation failed: Semantic mismatch
            Original: \(original)
            Regenerated: \(regenerated)
            """
        }
    }
}

// MARK: - Parser Printer Builder

/// Builder for creating parser-printer combinations with specific configurations
public struct ParserPrinterBuilder {
    private var configuration: PrettyPrinter.Configuration = PrettyPrinter.Configuration()
    private var validateRoundTrips: Bool = true

    public init() {}

    /// Sets the indentation configuration for the printer
    public func indentSize(_ size: Int) -> ParserPrinterBuilder {
        var builder = self
        builder.configuration.indentSize = size
        return builder
    }

    /// Sets whether to use spaces or tabs for indentation
    public func useSpaces(_ useSpaces: Bool) -> ParserPrinterBuilder {
        var builder = self
        builder.configuration.useSpaces = useSpaces
        return builder
    }

    /// Enables or disables round-trip validation
    public func validateRoundTrips(_ validate: Bool) -> ParserPrinterBuilder {
        var builder = self
        builder.validateRoundTrips = validate
        return builder
    }

    /// Builds the configured parser-printer
    public func build() -> ParserPrinter {
        return ParserPrinter(configuration: configuration, validateRoundTrips: validateRoundTrips)
    }
}

// MARK: - Testing Utilities

extension ParserPrinter {
    /// Convenience method for testing round-trip parsing with multiple test cases
    public static func validateTestCases(_ testCases: [String]) throws -> [RoundTripResult] {
        let parserPrinter = ParserPrinter()
        var results: [RoundTripResult] = []

        for (index, testCase) in testCases.enumerated() {
            do {
                let (ast, regenerated) = try parserPrinter.roundTrip(testCase)
                results.append(.success(
                    index: index,
                    original: testCase,
                    ast: ast,
                    regenerated: regenerated
                ))
            } catch {
                results.append(.failure(
                    index: index,
                    original: testCase,
                    error: error
                ))
            }
        }

        return results
    }

    /// Result of a round-trip test
    public enum RoundTripResult {
        case success(index: Int, original: String, ast: [Statement], regenerated: String)
        case failure(index: Int, original: String, error: Error)

        public var isSuccess: Bool {
            switch self {
            case .success: return true
            case .failure: return false
            }
        }

        public var index: Int {
            switch self {
            case .success(let index, _, _, _): return index
            case .failure(let index, _, _): return index
            }
        }
    }
}

// MARK: - Grammar Fragment Testing

extension ParserPrinter {
    /// Tests specific grammar fragments in isolation
    public func testGrammarFragments() throws -> [GrammarTestResult] {
        let fragments: [(name: String, code: String)] = [
            ("variable_declaration", "variable x: integer ← 42"),
            ("constant_declaration", "constant PI: real ← 3.14159"),
            ("if_statement", "if x > 0 then\n  y ← x\nendif"),
            ("while_loop", "while count < 10 do\n  count ← count + 1\nendwhile"),
            ("for_range", "for i ← 1 to 10 do\n  writeLine(i)\nendfor"),
            ("for_each", "for item in items do\n  process(item)\nendfor"),
            ("function_declaration", "function add(a: integer, b: integer): integer\n  return a + b\nendfunction"),
            ("procedure_declaration", "procedure greet(name: string)\n  writeLine(\"Hello, \" + name)\nendprocedure"),
            ("assignment", "x ← 42"),
            ("array_assignment", "arr[0] ← value"),
            ("expression_statement", "calculate(x, y)"),
            ("return_statement", "return result"),
            ("break_statement", "break")
        ]

        var results: [GrammarTestResult] = []

        for fragment in fragments {
            do {
                let (ast, regenerated) = try roundTrip(fragment.code)
                results.append(.success(
                    fragmentName: fragment.name,
                    original: fragment.code,
                    ast: ast,
                    regenerated: regenerated
                ))
            } catch {
                results.append(.failure(
                    fragmentName: fragment.name,
                    original: fragment.code,
                    error: error
                ))
            }
        }

        return results
    }

    /// Result of testing a specific grammar fragment
    public enum GrammarTestResult {
        case success(fragmentName: String, original: String, ast: [Statement], regenerated: String)
        case failure(fragmentName: String, original: String, error: Error)

        public var isSuccess: Bool {
            switch self {
            case .success: return true
            case .failure: return false
            }
        }

        public var fragmentName: String {
            switch self {
            case .success(let name, _, _, _): return name
            case .failure(let name, _, _): return name
            }
        }
    }
}
