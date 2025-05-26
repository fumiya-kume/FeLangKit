import Testing
import Foundation
@testable import FeLangCore

/// Golden file tests for semantic error formatting.
/// Tests the ErrorFormatter integration with SemanticError to ensure consistent error message formatting.
@Suite("SemanticError Golden File Tests")
struct SemanticErrorGoldenTests {
    
    // MARK: - Error Formatting Tests
    
    @Test("Type mismatch error formatting")
    func testTypeMismatchFormatting() {
        let pos = SourcePosition(line: 5, column: 12)
        let error = SemanticError.typeMismatch(expected: .integer, actual: .string, at: pos)
        
        let formatted = ErrorFormatter.format(error)
        let expected = """
        SemanticError: Type mismatch
          Expected: integer
          Found: string
          Position: line 5, column 12
        """
        
        #expect(normalizeWhitespace(formatted) == normalizeWhitespace(expected))
    }
    
    @Test("Undeclared variable error formatting")
    func testUndeclaredVariableFormatting() {
        let pos = SourcePosition(line: 3, column: 8)
        let error = SemanticError.undeclaredVariable("myVar", at: pos)
        
        let formatted = ErrorFormatter.format(error)
        let expected = """
        SemanticError: Undeclared variable
          Variable: 'myVar'
          Position: line 3, column 8
          Note: Variable must be declared before use
        """
        
        #expect(normalizeWhitespace(formatted) == normalizeWhitespace(expected))
    }
    
    @Test("Function argument count error formatting")
    func testFunctionArgumentCountFormatting() {
        let pos = SourcePosition(line: 10, column: 15)
        let error = SemanticError.incorrectArgumentCount(function: "calculateSum", expected: 2, actual: 3, at: pos)
        
        let formatted = ErrorFormatter.format(error)
        let expected = """
        SemanticError: Incorrect argument count
          Function: 'calculateSum'
          Expected: 2 arguments
          Found: 3 arguments
          Position: line 10, column 15
        """
        
        #expect(normalizeWhitespace(formatted) == normalizeWhitespace(expected))
    }
    
    @Test("Too many errors formatting")
    func testTooManyErrorsFormatting() {
        let error = SemanticError.tooManyErrors(count: 100)
        
        let formatted = ErrorFormatter.format(error)
        let expected = """
        SemanticError: Too many semantic errors
          Analysis stopped after 100 errors
          Note: Fix some errors and try again
        """
        
        #expect(normalizeWhitespace(formatted) == normalizeWhitespace(expected))
    }
    
    // MARK: - ErrorFormatter with SymbolTable Context
    
    @Test("Error formatting with symbol table suggestions")
    func testErrorFormattingWithSymbolTable() {
        let symbolTable = SymbolTable()
        let pos = SourcePosition(line: 1, column: 1)
        
        // Add some symbols to the table
        try! symbolTable.declareVariable("userName", type: .string, at: pos)
        try! symbolTable.declareVariable("userAge", type: .integer, at: pos)
        try! symbolTable.declareVariable("userEmail", type: .string, at: pos)
        
        // Create error for similar variable name
        let error = SemanticError.undeclaredVariable("userNam", at: SourcePosition(line: 5, column: 3))
        
        let formatted = ErrorFormatter.formatSemanticError(error, symbolTable: symbolTable)
        
        // Should include suggestions
        #expect(formatted.contains("Did you mean:"))
        #expect(formatted.contains("userName"))
    }
    
    @Test("Type conversion suggestions")
    func testTypeConversionSuggestions() {
        let pos = SourcePosition(line: 8, column: 4)
        let error = SemanticError.typeMismatch(expected: .real, actual: .integer, at: pos)
        
        let formatted = ErrorFormatter.formatSemanticError(error)
        
        // Should include automatic conversion note
        #expect(formatted.contains("Note: Integer values are automatically converted to real"))
    }
    
    // MARK: - Complex Error Scenarios
    
    @Test("Array index type mismatch formatting")
    func testArrayIndexTypeMismatchFormatting() {
        let pos = SourcePosition(line: 15, column: 7)
        let error = SemanticError.arrayIndexTypeMismatch(expected: .integer, actual: .string, at: pos)
        
        let formatted = ErrorFormatter.format(error)
        let expected = """
        SemanticError: Array index type mismatch
          Expected: integer
          Found: string
          Position: line 15, column 7
          Note: Array indices must be integers
        """
        
        #expect(normalizeWhitespace(formatted) == normalizeWhitespace(expected))
    }
    
    @Test("Cyclic dependency formatting")
    func testCyclicDependencyFormatting() {
        let pos = SourcePosition(line: 20, column: 1)
        let error = SemanticError.cyclicDependency(["a", "b", "c", "a"], at: pos)
        
        let formatted = ErrorFormatter.format(error)
        
        #expect(formatted.contains("Cyclic dependency detected"))
        #expect(formatted.contains("a -> b -> c -> a"))
        #expect(formatted.contains("line 20, column 1"))
    }
    
    // MARK: - Integration with SemanticErrorReporter
    
    @Test("Integration with SemanticErrorReporter")
    func testIntegrationWithSemanticErrorReporter() {
        let reporter = SemanticErrorReporter()
        let symbolTable = SymbolTable()
        
        // Add multiple types of errors
        let errors = [
            SemanticError.undeclaredVariable("x", at: SourcePosition(line: 1, column: 5)),
            SemanticError.typeMismatch(expected: .integer, actual: .string, at: SourcePosition(line: 2, column: 8)),
            SemanticError.functionAlreadyDeclared("main", at: SourcePosition(line: 3, column: 1))
        ]
        
        for error in errors {
            reporter.report(error)
        }
        
        let result = reporter.createResult(symbolTable: symbolTable)
        
        // Test that all errors are properly formatted
        for error in result.errors {
            let formatted = ErrorFormatter.format(error)
            #expect(formatted.contains("SemanticError:"))
            #expect(!formatted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
    
    // MARK: - Helper Functions
    
    private func normalizeWhitespace(_ text: String) -> String {
        return text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}