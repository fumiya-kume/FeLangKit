import Foundation
import Testing
@testable import FeLangCore

/// Utilities for managing golden file-based ParseError testing.
/// This module provides comprehensive infrastructure for loading, parsing, and validating
/// golden file test cases with proper error handling and regression detection.
public struct ParseErrorTestUtils {

        // MARK: - Constants

    private static let goldenFilesPath = "Tests/FeLangCoreTests/ParseError/GoldenFiles"
    private static let testCasesPath = "Tests/FeLangCoreTests/ParseError/TestCases"

    // Golden file format constants
    private static let testCaseHeaderPrefix = "=== Test Case:"
    private static let testCaseHeaderSuffix = " ==="

    // MARK: - Golden File Management

    /// Represents a single test case from a golden file.
    public struct GoldenTestCase: Equatable, Sendable {
        public let name: String
        public let input: String
        public let expectedError: String
        public let category: ErrorCategory

        public init(name: String, input: String, expectedError: String, category: ErrorCategory) {
            self.name = name
            self.input = input
            self.expectedError = expectedError
            self.category = category
        }
    }

    /// Categories of parse errors for organized testing.
    public enum ErrorCategory: String, CaseIterable, Sendable {
        case syntaxErrors = "syntax-errors"
        case semanticErrors = "semantic-errors"
        case tokenizerErrors = "tokenizer-errors"
        case complexErrors = "complex-errors"
        case edgeCases = "edge-cases"

        public var description: String {
            switch self {
            case .syntaxErrors:
                return "Syntax Errors - Invalid language constructs"
            case .semanticErrors:
                return "Semantic Errors - Type mismatches and scope issues"
            case .tokenizerErrors:
                return "Tokenizer Errors - Lexical analysis failures"
            case .complexErrors:
                return "Complex Errors - Multi-layer parsing issues"
            case .edgeCases:
                return "Edge Cases - Boundary and unusual input scenarios"
            }
        }
    }

    // MARK: - Golden File Loading

    /// Loads test cases from a golden file for the specified error category.
    /// - Parameter category: The error category to load tests for
    /// - Returns: Array of golden test cases
    /// - Throws: GoldenFileError if loading fails
    public static func loadGoldenFile(for category: ErrorCategory) throws -> [GoldenTestCase] {
        let filename = "\(category.rawValue).golden"
        let fileURL = URL(fileURLWithPath: goldenFilesPath).appendingPathComponent(filename)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw GoldenFileError.fileNotFound(filename)
        }

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        return try parseGoldenFile(content: content, category: category)
    }

    /// Loads all golden test cases from all categories.
    /// - Returns: Dictionary mapping categories to their test cases
    /// - Throws: GoldenFileError if any file loading fails
    public static func loadAllGoldenFiles() throws -> [ErrorCategory: [GoldenTestCase]] {
        var allTestCases: [ErrorCategory: [GoldenTestCase]] = [:]

        for category in ErrorCategory.allCases {
            do {
                allTestCases[category] = try loadGoldenFile(for: category)
            } catch GoldenFileError.fileNotFound(_) {
                // Skip missing files - they might not be created yet
                allTestCases[category] = []
            }
        }

        return allTestCases
    }

    // MARK: - Golden File Parsing

    private static func parseGoldenFile(content: String, category: ErrorCategory) throws -> [GoldenTestCase] {
        var testCases: [GoldenTestCase] = []
        let lines = content.components(separatedBy: .newlines)
        var currentIndex = 0

        while currentIndex < lines.count {
            // Skip empty lines and comments
            if lines[currentIndex].trimmingCharacters(in: .whitespaces).isEmpty ||
               lines[currentIndex].trimmingCharacters(in: .whitespaces).hasPrefix("#") {
                currentIndex += 1
                continue
            }

            // Parse test case
            if let testCase = try parseTestCase(from: lines, startIndex: &currentIndex, category: category) {
                testCases.append(testCase)
            }
        }

        return testCases
    }

    private static func parseTestCase(
        from lines: [String],
        startIndex: inout Int,
        category: ErrorCategory
    ) throws -> GoldenTestCase? {
        guard startIndex < lines.count else { return nil }

                let headerLine = lines[startIndex].trimmingCharacters(in: .whitespaces)

        // Look for test case header: === Test Case: name ===
        guard headerLine.hasPrefix(testCaseHeaderPrefix) && headerLine.hasSuffix(testCaseHeaderSuffix) else {
            startIndex += 1
            return nil
        }

        let nameStartIndex = headerLine.index(headerLine.startIndex, offsetBy: testCaseHeaderPrefix.count)
        let nameEndIndex = headerLine.index(headerLine.endIndex, offsetBy: -testCaseHeaderSuffix.count)
        let name = String(headerLine[nameStartIndex..<nameEndIndex]).trimmingCharacters(in: .whitespaces)

        startIndex += 1

        // Parse Input section
        guard startIndex < lines.count,
              lines[startIndex].trimmingCharacters(in: .whitespaces) == "Input:" else {
            throw GoldenFileError.malformedTestCase(name, "Missing 'Input:' section")
        }
        startIndex += 1

        var input = ""
        while startIndex < lines.count {
            let line = lines[startIndex]
            if line.trimmingCharacters(in: .whitespaces) == "Expected Error:" {
                break
            }
            input += line + "\n"
            startIndex += 1
        }
        input = input.trimmingCharacters(in: .newlines)

        // Parse Expected Error section
        guard startIndex < lines.count,
              lines[startIndex].trimmingCharacters(in: .whitespaces) == "Expected Error:" else {
            throw GoldenFileError.malformedTestCase(name, "Missing 'Expected Error:' section")
        }
        startIndex += 1

        var expectedError = ""
        while startIndex < lines.count {
            let line = lines[startIndex]
            if line.trimmingCharacters(in: .whitespaces).hasPrefix(testCaseHeaderPrefix) {
                break
            }
            if line.trimmingCharacters(in: .whitespaces).isEmpty && expectedError.isEmpty {
                startIndex += 1
                continue
            }
            expectedError += line + "\n"
            startIndex += 1
        }
        expectedError = expectedError.trimmingCharacters(in: .newlines)

        guard !expectedError.isEmpty else {
            throw GoldenFileError.malformedTestCase(name, "Expected error is empty")
        }

        // Input can be empty for edge cases (that's valid)

        return GoldenTestCase(name: name, input: input, expectedError: expectedError, category: category)
    }

    // MARK: - Golden File Generation

    /// Generates a golden file for the specified category with the provided test cases.
    /// This is useful for updating golden files when error messages change intentionally.
    /// - Parameters:
    ///   - category: The error category to generate the file for
    ///   - testCases: The test cases to include in the golden file
    /// - Throws: GoldenFileError if file generation fails
    public static func generateGoldenFile(for category: ErrorCategory, testCases: [GoldenTestCase]) throws {
        let filename = "\(category.rawValue).golden"
        let fileURL = URL(fileURLWithPath: goldenFilesPath).appendingPathComponent(filename)

        // Ensure directory exists
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: goldenFilesPath),
            withIntermediateDirectories: true,
            attributes: nil
        )

        var content = "# \(category.description)\n"
        content += "# Generated on \(Date())\n"
        content += "# This file contains expected error messages for regression testing\n\n"

        for testCase in testCases {
            content += "\(testCaseHeaderPrefix) \(testCase.name)\(testCaseHeaderSuffix)\n"
            content += "Input:\n"
            content += testCase.input + "\n"
            content += "Expected Error:\n"
            content += testCase.expectedError + "\n\n"
        }

        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Test Execution

    /// Executes a single golden test case and validates the result.
    /// - Parameter testCase: The test case to execute
    /// - Throws: ParseErrorTestError if validation fails
    public static func executeGoldenTest(_ testCase: GoldenTestCase) throws {
        let actualError: String

        do {
            // Try to parse the input - it should fail
            let tokens = try ParsingTokenizer().tokenize(testCase.input)

            // Try statement parsing first
            do {
                let parser = StatementParser()
                _ = try parser.parseStatements(from: tokens)

                // If statement parsing succeeds, try expression parsing
                let expressionParser = ExpressionParser()
                _ = try expressionParser.parseExpression(from: tokens)

                // If both succeed, this is an unexpected success
                throw ParseErrorTestError.unexpectedSuccess(testCase.name, testCase.input)
            } catch {
                // Format the caught error
                actualError = ErrorFormatter.formatWithContext(error, input: testCase.input)
            }
        } catch {
            // Tokenizer error - format it
            actualError = ErrorFormatter.format(error)
        }

        // Normalize whitespace for comparison
        let normalizedActual = normalizeErrorMessage(actualError)
        let normalizedExpected = normalizeErrorMessage(testCase.expectedError)

        guard normalizedActual == normalizedExpected else {
            throw ParseErrorTestError.errorMismatch(
                testCase: testCase.name,
                expected: testCase.expectedError,
                actual: actualError
            )
        }
    }

    /// Executes all test cases for a specific category.
    /// - Parameter category: The error category to test
    /// - Throws: ParseErrorTestError if any test fails
    public static func executeGoldenTests(for category: ErrorCategory) throws {
        let testCases = try loadGoldenFile(for: category)

        for testCase in testCases {
            try executeGoldenTest(testCase)
        }
    }

    // MARK: - Utility Methods

    /// Normalizes error messages for comparison by standardizing whitespace.
    private static func normalizeErrorMessage(_ message: String) -> String {
        return message
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Creates initial golden files with empty structure if they don't exist.
    public static func createInitialGoldenFiles() throws {
        // Ensure directories exist
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: goldenFilesPath),
            withIntermediateDirectories: true,
            attributes: nil
        )

        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: testCasesPath),
            withIntermediateDirectories: true,
            attributes: nil
        )

        for category in ErrorCategory.allCases {
            let filename = "\(category.rawValue).golden"
            let fileURL = URL(fileURLWithPath: goldenFilesPath).appendingPathComponent(filename)

            if !FileManager.default.fileExists(atPath: fileURL.path) {
                let initialContent = "# \(category.description)\n" +
                                   "# This file will contain expected error messages for regression testing\n" +
                                   "# Add test cases in the format:\n" +
                                   "# \(testCaseHeaderPrefix) test_name\(testCaseHeaderSuffix)\n" +
                                   "# Input:\n" +
                                   "# [your test input here]\n" +
                                   "# Expected Error:\n" +
                                   "# [expected error message here]\n\n"

                try initialContent.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        }
    }
}

// MARK: - Error Types

/// Errors that can occur during golden file operations.
public enum GoldenFileError: Error, LocalizedError {
    case fileNotFound(String)
    case malformedTestCase(String, String)
    case writeError(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let filename):
            return "Golden file not found: \(filename)"
        case .malformedTestCase(let name, let details):
            return "Malformed test case '\(name)': \(details)"
        case .writeError(let details):
            return "Failed to write golden file: \(details)"
        }
    }
}

/// Errors that can occur during test execution.
public enum ParseErrorTestError: Error, LocalizedError {
    case unexpectedSuccess(String, String)
    case errorMismatch(testCase: String, expected: String, actual: String)

    public var errorDescription: String? {
        switch self {
        case .unexpectedSuccess(let testName, let input):
            return "Test '\(testName)' expected to fail but succeeded with input: \(input)"
        case .errorMismatch(let testCase, let expected, let actual):
            return """
            Error mismatch in test '\(testCase)':
            Expected:
            \(expected)

            Actual:
            \(actual)
            """
        }
    }
}
