import Testing
import Foundation
@testable import FeLangCore

/// Golden file tests for semantic error formatting consistency.
/// This test suite ensures that semantic error messages remain consistent across changes
/// and provides regression protection for all semantic error scenarios.
@Suite("SemanticError Golden File Tests")
struct SemanticErrorGoldenTests {

    // MARK: - Setup

    private static let goldenFilesPath = "Tests/FeLangCoreTests/SemanticError/GoldenFiles"
    
    init() async throws {
        // Ensure golden files structure exists
        try SemanticErrorTestUtils.createInitialGoldenFiles()
        
        // Initialize golden files with sample test cases if they're empty
        try await initializeGoldenFilesIfNeeded()
    }

    // MARK: - Golden File Tests by Category

    @Test("Type Error Golden File Tests")
    func testTypeErrorsAgainstGoldenFile() async throws {
        try SemanticErrorTestUtils.executeGoldenTests(for: .typeErrors)
    }

    @Test("Scope Error Golden File Tests")
    func testScopeErrorsAgainstGoldenFile() async throws {
        try SemanticErrorTestUtils.executeGoldenTests(for: .scopeErrors)
    }

    @Test("Function Error Golden File Tests")
    func testFunctionErrorsAgainstGoldenFile() async throws {
        try SemanticErrorTestUtils.executeGoldenTests(for: .functionErrors)
    }

    @Test("Control Flow Error Golden File Tests")
    func testControlFlowErrorsAgainstGoldenFile() async throws {
        try SemanticErrorTestUtils.executeGoldenTests(for: .controlFlowErrors)
    }

    @Test("Array Error Golden File Tests")
    func testArrayErrorsAgainstGoldenFile() async throws {
        try SemanticErrorTestUtils.executeGoldenTests(for: .arrayErrors)
    }

    @Test("Record Error Golden File Tests")
    func testRecordErrorsAgainstGoldenFile() async throws {
        try SemanticErrorTestUtils.executeGoldenTests(for: .recordErrors)
    }

    @Test("Complex Semantic Error Golden File Tests")
    func testComplexSemanticErrorsAgainstGoldenFile() async throws {
        try SemanticErrorTestUtils.executeGoldenTests(for: .complexSemanticErrors)
    }

    // MARK: - Comprehensive Error Coverage Tests

    @Test("All Semantic Error Categories Coverage")
    func testAllSemanticErrorCategoriesCoverage() async throws {
        let allTestCases = try SemanticErrorTestUtils.loadAllGoldenFiles()
        
        // Verify we have test cases for all major error categories
        let allCategories = SemanticErrorTestUtils.SemanticErrorCategory.allCases
        
        for category in allCategories {
            guard let testCases = allTestCases[category] else {
                Issue.record("Missing test cases for category: \(category)")
                continue
            }
            
            #expect(!testCases.isEmpty, "Category \(category) should have test cases")
        }
        
        // Verify total number of test cases is reasonable
        let totalTestCases = allTestCases.values.reduce(0) { $0 + $1.count }
        #expect(totalTestCases >= 20, "Should have at least 20 semantic error test cases")
    }

    @Test("Error Message Consistency Across Categories")
    func testErrorMessageConsistencyAcrossCategories() async throws {
        let allTestCases = try SemanticErrorTestUtils.loadAllGoldenFiles()
        
        for (category, testCases) in allTestCases {
            for testCase in testCases {
                // Verify basic formatting consistency
                #expect(testCase.expectedError.contains("SemanticError:"), 
                       "Error in \(category) should start with 'SemanticError:'")
                
                // Verify position information is included where expected
                if testCase.input.contains("at line") || testCase.name.contains("position") {
                    #expect(testCase.expectedError.contains("line"), 
                           "Error in \(category) should include position information")
                }
                
                // Verify error messages are not empty
                #expect(!testCase.expectedError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       "Error message should not be empty")
            }
        }
    }

    // MARK: - Regression Tests

    @Test("Golden File Regression Protection")
    func testGoldenFileRegressionProtection() async throws {
        // This test ensures that any changes to error formatting are intentional
        // by comparing against the stored golden files
        
        let allTestCases = try SemanticErrorTestUtils.loadAllGoldenFiles()
        var totalTests = 0
        var passedTests = 0
        
        for (category, testCases) in allTestCases {
            for testCase in testCases {
                totalTests += 1
                
                do {
                    // Parse and format the error from the test case
                    let actualError = try SemanticErrorTestUtils.parseErrorFromInput(testCase.input)
                    let actualFormatted = ErrorFormatter.format(actualError)
                    
                    if actualFormatted == testCase.expectedError {
                        passedTests += 1
                    } else {
                        Issue.record("""
                            Golden file mismatch in \(category) - \(testCase.name):
                            Expected: \(testCase.expectedError)
                            Actual:   \(actualFormatted)
                            """)
                    }
                } catch {
                    Issue.record("Failed to process test case \(testCase.name) in \(category): \(error)")
                }
            }
        }
        
        // Require at least 90% of tests to pass
        let passRate = Double(passedTests) / Double(totalTests)
        #expect(passRate >= 0.9, "At least 90% of golden file tests should pass")
    }

    // MARK: - Private Helpers

    private func initializeGoldenFilesIfNeeded() async throws {
        // Check if golden files need initialization with default test cases
        let categories = SemanticErrorTestUtils.SemanticErrorCategory.allCases
        
        for category in categories {
            do {
                let testCases = try SemanticErrorTestUtils.loadGoldenFile(for: category)
                if testCases.isEmpty {
                    try await createDefaultTestCases(for: category)
                }
            } catch {
                // Create default test cases if file doesn't exist
                try await createDefaultTestCases(for: category)
            }
        }
    }
    
    private func createDefaultTestCases(for category: SemanticErrorTestUtils.SemanticErrorCategory) async throws {
        let defaultTestCases = SemanticErrorTestUtils.createDefaultTestCases(for: category)
        try SemanticErrorTestUtils.saveGoldenFile(testCases: defaultTestCases, for: category)
    }
}

/// Utilities for managing golden file-based semantic error testing.
/// This module provides comprehensive infrastructure for loading, parsing, and validating
/// golden file test cases for semantic errors.
public struct SemanticErrorTestUtils {

    // MARK: - Constants

    private static let goldenFilesPath = "Tests/FeLangCoreTests/SemanticError/GoldenFiles"
    private static let testCasesPath = "Tests/FeLangCoreTests/SemanticError/TestCases"

    // Golden file format constants
    private static let testCaseHeaderPrefix = "=== Test Case:"
    private static let testCaseHeaderSuffix = " ==="

    // MARK: - Data Structures

    /// Represents a single semantic error test case from a golden file.
    public struct SemanticGoldenTestCase: Equatable, Sendable {
        public let name: String
        public let input: String
        public let expectedError: String
        public let category: SemanticErrorCategory

        public init(name: String, input: String, expectedError: String, category: SemanticErrorCategory) {
            self.name = name
            self.input = input
            self.expectedError = expectedError
            self.category = category
        }
    }

    /// Categories of semantic errors for organized testing.
    public enum SemanticErrorCategory: String, CaseIterable, Sendable {
        case typeErrors = "type-errors"
        case scopeErrors = "scope-errors"
        case functionErrors = "function-errors"
        case controlFlowErrors = "control-flow-errors"
        case arrayErrors = "array-errors"
        case recordErrors = "record-errors"
        case complexSemanticErrors = "complex-semantic-errors"

        public var description: String {
            switch self {
            case .typeErrors:
                return "Type Errors - Type mismatches and invalid conversions"
            case .scopeErrors:
                return "Scope Errors - Variable declaration and scope issues"
            case .functionErrors:
                return "Function Errors - Function calls and return type issues"
            case .controlFlowErrors:
                return "Control Flow Errors - Break, return, and unreachable code"
            case .arrayErrors:
                return "Array Errors - Array access and indexing issues"
            case .recordErrors:
                return "Record Errors - Field access and record type issues"
            case .complexSemanticErrors:
                return "Complex Semantic Errors - Multi-faceted semantic issues"
            }
        }
    }

    // MARK: - Golden File Management

    /// Creates the initial golden files directory structure.
    public static func createInitialGoldenFiles() throws {
        let fileManager = FileManager.default
        let goldenPath = URL(fileURLWithPath: goldenFilesPath)
        
        if !fileManager.fileExists(atPath: goldenPath.path) {
            try fileManager.createDirectory(at: goldenPath, withIntermediateDirectories: true)
        }
    }

    /// Loads test cases from a golden file for the specified semantic error category.
    /// - Parameter category: The semantic error category to load tests for
    /// - Returns: Array of semantic golden test cases
    /// - Throws: GoldenFileError if loading fails
    public static func loadGoldenFile(for category: SemanticErrorCategory) throws -> [SemanticGoldenTestCase] {
        let filename = "\(category.rawValue).golden"
        let fileURL = URL(fileURLWithPath: goldenFilesPath).appendingPathComponent(filename)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw GoldenFileError.fileNotFound(filename)
        }

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        return try parseSemanticGoldenFile(content: content, category: category)
    }

    /// Loads all semantic golden test cases from all categories.
    /// - Returns: Dictionary mapping categories to their test cases
    /// - Throws: GoldenFileError if any file loading fails
    public static func loadAllGoldenFiles() throws -> [SemanticErrorCategory: [SemanticGoldenTestCase]] {
        var allTestCases: [SemanticErrorCategory: [SemanticGoldenTestCase]] = [:]

        for category in SemanticErrorCategory.allCases {
            do {
                allTestCases[category] = try loadGoldenFile(for: category)
            } catch GoldenFileError.fileNotFound(_) {
                // Skip missing files - they might not be created yet
                allTestCases[category] = []
            }
        }

        return allTestCases
    }

    /// Saves test cases to a golden file.
    /// - Parameters:
    ///   - testCases: Array of test cases to save
    ///   - category: The category to save tests for
    /// - Throws: GoldenFileError if saving fails
    public static func saveGoldenFile(testCases: [SemanticGoldenTestCase], for category: SemanticErrorCategory) throws {
        let filename = "\(category.rawValue).golden"
        let fileURL = URL(fileURLWithPath: goldenFilesPath).appendingPathComponent(filename)
        
        let content = formatGoldenFileContent(testCases: testCases)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Test Execution

    /// Executes golden tests for a specific category.
    /// - Parameter category: The semantic error category to test
    /// - Throws: Testing errors if any test fails
    public static func executeGoldenTests(for category: SemanticErrorCategory) throws {
        let testCases = try loadGoldenFile(for: category)
        
        for testCase in testCases {
            do {
                let actualError = try parseErrorFromInput(testCase.input)
                let actualFormatted = ErrorFormatter.format(actualError)
                
                if actualFormatted != testCase.expectedError {
                    Issue.record("""
                        Golden file test failed for \(category) - \(testCase.name):
                        Expected: \(testCase.expectedError)
                        Actual:   \(actualFormatted)
                        """)
                }
            } catch {
                Issue.record("Failed to execute test case \(testCase.name): \(error)")
            }
        }
    }

    // MARK: - Error Parsing

    /// Parses a semantic error from test input.
    /// - Parameter input: The test input string
    /// - Returns: A semantic error instance
    /// - Throws: Parsing errors if the input is invalid
    public static func parseErrorFromInput(_ input: String) throws -> SemanticError {
        // Parse the test input to extract error information
        // Format: "ErrorType|param1|param2|line|column"
        let components = input.components(separatedBy: "|")
        
        guard components.count >= 3 else {
            throw GoldenFileError.invalidTestCase("Invalid input format: \(input)")
        }
        
        let errorType = components[0]
        let line = Int(components[components.count - 2]) ?? 1
        let column = Int(components[components.count - 1]) ?? 1
        let position = SourcePosition(line: line, column: column)
        
        switch errorType {
        case "undeclaredVariable":
            guard components.count >= 4 else { throw GoldenFileError.invalidTestCase("Missing variable name") }
            return .undeclaredVariable(components[1], at: position)
            
        case "typeMismatch":
            guard components.count >= 5 else { throw GoldenFileError.invalidTestCase("Missing type information") }
            let expected = try parseFeType(components[1])
            let actual = try parseFeType(components[2])
            return .typeMismatch(expected: expected, actual: actual, at: position)
            
        case "incompatibleTypes":
            guard components.count >= 6 else { throw GoldenFileError.invalidTestCase("Missing type or operation") }
            let type1 = try parseFeType(components[1])
            let type2 = try parseFeType(components[2])
            let operation = components[3]
            return .incompatibleTypes(type1, type2, operation: operation, at: position)
            
        case "incorrectArgumentCount":
            guard components.count >= 6 else { throw GoldenFileError.invalidTestCase("Missing function info") }
            let function = components[1]
            let expected = Int(components[2]) ?? 0
            let actual = Int(components[3]) ?? 0
            return .incorrectArgumentCount(function: function, expected: expected, actual: actual, at: position)
            
        case "breakOutsideLoop":
            return .breakOutsideLoop(at: position)
            
        case "arrayIndexTypeMismatch":
            guard components.count >= 5 else { throw GoldenFileError.invalidTestCase("Missing type information") }
            let expected = try parseFeType(components[1])
            let actual = try parseFeType(components[2])
            return .arrayIndexTypeMismatch(expected: expected, actual: actual, at: position)
            
        case "undeclaredField":
            guard components.count >= 5 else { throw GoldenFileError.invalidTestCase("Missing field info") }
            let fieldName = components[1]
            let recordType = components[2]
            return .undeclaredField(fieldName: fieldName, recordType: recordType, at: position)
            
        case "tooManyErrors":
            guard components.count >= 2 else { throw GoldenFileError.invalidTestCase("Missing error count") }
            let count = Int(components[1]) ?? 100
            return .tooManyErrors(count: count)
            
        default:
            throw GoldenFileError.invalidTestCase("Unknown error type: \(errorType)")
        }
    }

    // MARK: - Default Test Cases

    /// Creates default test cases for a given category.
    /// - Parameter category: The category to create test cases for
    /// - Returns: Array of default test cases
    public static func createDefaultTestCases(for category: SemanticErrorCategory) -> [SemanticGoldenTestCase] {
        switch category {
        case .typeErrors:
            return createTypeErrorTestCases()
        case .scopeErrors:
            return createScopeErrorTestCases()
        case .functionErrors:
            return createFunctionErrorTestCases()
        case .controlFlowErrors:
            return createControlFlowErrorTestCases()
        case .arrayErrors:
            return createArrayErrorTestCases()
        case .recordErrors:
            return createRecordErrorTestCases()
        case .complexSemanticErrors:
            return createComplexSemanticErrorTestCases()
        }
    }

    // MARK: - Private Helpers

    private static func parseSemanticGoldenFile(content: String, category: SemanticErrorCategory) throws -> [SemanticGoldenTestCase] {
        var testCases: [SemanticGoldenTestCase] = []
        let lines = content.components(separatedBy: .newlines)
        
        var currentTestCase: SemanticGoldenTestCase?
        var currentInput = ""
        var currentExpectedError = ""
        var inExpectedSection = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.hasPrefix(testCaseHeaderPrefix) && trimmedLine.hasSuffix(testCaseHeaderSuffix) {
                // Save previous test case if exists
                if let testCase = currentTestCase {
                    testCases.append(testCase)
                }
                
                // Start new test case
                let nameStart = testCaseHeaderPrefix.count
                let nameEnd = trimmedLine.count - testCaseHeaderSuffix.count
                let name = String(trimmedLine[trimmedLine.index(trimmedLine.startIndex, offsetBy: nameStart)..<trimmedLine.index(trimmedLine.startIndex, offsetBy: nameEnd)])
                
                currentTestCase = SemanticGoldenTestCase(name: name, input: "", expectedError: "", category: category)
                currentInput = ""
                currentExpectedError = ""
                inExpectedSection = false
                
            } else if trimmedLine == "EXPECTED:" {
                inExpectedSection = true
            } else if !trimmedLine.isEmpty && trimmedLine != "INPUT:" {
                if inExpectedSection {
                    if !currentExpectedError.isEmpty {
                        currentExpectedError += "\n"
                    }
                    currentExpectedError += line
                } else {
                    if !currentInput.isEmpty {
                        currentInput += "\n"
                    }
                    currentInput += line
                }
            }
            
            // Update current test case
            if var testCase = currentTestCase {
                testCase = SemanticGoldenTestCase(
                    name: testCase.name,
                    input: currentInput,
                    expectedError: currentExpectedError,
                    category: category
                )
                currentTestCase = testCase
            }
        }
        
        // Add final test case
        if let testCase = currentTestCase {
            testCases.append(testCase)
        }
        
        return testCases
    }

    private static func formatGoldenFileContent(testCases: [SemanticGoldenTestCase]) -> String {
        var content = ""
        
        for testCase in testCases {
            content += "\(testCaseHeaderPrefix) \(testCase.name) \(testCaseHeaderSuffix)\n"
            content += "INPUT:\n"
            content += testCase.input
            content += "\n\nEXPECTED:\n"
            content += testCase.expectedError
            content += "\n\n"
        }
        
        return content
    }

    private static func parseFeType(_ typeString: String) throws -> FeType {
        switch typeString {
        case "integer":
            return .integer
        case "real":
            return .real
        case "string":
            return .string
        case "character":
            return .character
        case "boolean":
            return .boolean
        case "void":
            return .void
        default:
            throw GoldenFileError.invalidTestCase("Unknown type: \(typeString)")
        }
    }

    // MARK: - Test Case Creators

    private static func createTypeErrorTestCases() -> [SemanticGoldenTestCase] {
        return [
            SemanticGoldenTestCase(
                name: "Basic Type Mismatch",
                input: "typeMismatch|integer|string|1|5",
                expectedError: """
                SemanticError: Type mismatch
                  at line 1, column 5
                  Expected type: integer
                  Actual type: string
                """,
                category: .typeErrors
            ),
            SemanticGoldenTestCase(
                name: "Incompatible Types in Assignment",
                input: "incompatibleTypes|integer|string|assignment|2|10",
                expectedError: """
                SemanticError: Incompatible types for operation 'assignment'
                  at line 2, column 10
                  Left type: integer
                  Right type: string
                """,
                category: .typeErrors
            )
        ]
    }

    private static func createScopeErrorTestCases() -> [SemanticGoldenTestCase] {
        return [
            SemanticGoldenTestCase(
                name: "Undeclared Variable",
                input: "undeclaredVariable|myVar|3|7",
                expectedError: """
                SemanticError: Undeclared variable 'myVar'
                  at line 3, column 7
                  Suggestion: Declare the variable before using it
                """,
                category: .scopeErrors
            )
        ]
    }

    private static func createFunctionErrorTestCases() -> [SemanticGoldenTestCase] {
        return [
            SemanticGoldenTestCase(
                name: "Incorrect Argument Count",
                input: "incorrectArgumentCount|testFunc|2|3|4|8",
                expectedError: """
                SemanticError: Incorrect argument count for function 'testFunc'
                  at line 4, column 8
                  Expected: 2 arguments
                  Actual: 3 arguments
                """,
                category: .functionErrors
            )
        ]
    }

    private static func createControlFlowErrorTestCases() -> [SemanticGoldenTestCase] {
        return [
            SemanticGoldenTestCase(
                name: "Break Outside Loop",
                input: "breakOutsideLoop|5|3",
                expectedError: """
                SemanticError: Break statement outside loop
                  at line 5, column 3
                  Suggestion: Use break only inside while or for loops
                """,
                category: .controlFlowErrors
            )
        ]
    }

    private static func createArrayErrorTestCases() -> [SemanticGoldenTestCase] {
        return [
            SemanticGoldenTestCase(
                name: "Array Index Type Mismatch",
                input: "arrayIndexTypeMismatch|integer|string|6|12",
                expectedError: """
                SemanticError: Array index type mismatch
                  at line 6, column 12
                  Expected type: integer
                  Actual type: string
                """,
                category: .arrayErrors
            )
        ]
    }

    private static func createRecordErrorTestCases() -> [SemanticGoldenTestCase] {
        return [
            SemanticGoldenTestCase(
                name: "Undeclared Field",
                input: "undeclaredField|middleName|Person|7|15",
                expectedError: """
                SemanticError: Undeclared field 'middleName' in record type 'Person'
                  at line 7, column 15
                  Suggestion: Check field name spelling or record type definition
                """,
                category: .recordErrors
            )
        ]
    }

    private static func createComplexSemanticErrorTestCases() -> [SemanticGoldenTestCase] {
        return [
            SemanticGoldenTestCase(
                name: "Too Many Errors",
                input: "tooManyErrors|100",
                expectedError: """
                SemanticError: Too many semantic errors (100), stopping analysis
                  Suggestion: Fix initial errors and re-run analysis
                """,
                category: .complexSemanticErrors
            )
        ]
    }
}