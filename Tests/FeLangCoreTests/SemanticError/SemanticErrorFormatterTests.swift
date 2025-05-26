import Testing
import Foundation
@testable import FeLangCore

/// Comprehensive tests for ErrorFormatter semantic error support.
/// This test suite validates that semantic errors are formatted consistently
/// and provide clear, actionable feedback to users.
@Suite("SemanticError ErrorFormatter Tests")
struct SemanticErrorFormatterTests {

    // MARK: - Basic Semantic Error Formatting Tests

    @Test("Type Mismatch Error Formatting")
    func testTypeMismatchErrorFormatting() async throws {
        let position = SourcePosition(line: 5, column: 10)
        let error = SemanticError.typeMismatch(expected: .integer, actual: .string, at: position)
        
        let formatted = ErrorFormatter.format(error)
        
        #expect(formatted.contains("SemanticError"))
        #expect(formatted.contains("Type mismatch"))
        #expect(formatted.contains("line 5, column 10"))
        #expect(formatted.contains("Expected type: integer"))
        #expect(formatted.contains("Actual type: string"))
    }

    @Test("Undeclared Variable Error Formatting")
    func testUndeclaredVariableErrorFormatting() async throws {
        let position = SourcePosition(line: 3, column: 7)
        let error = SemanticError.undeclaredVariable("myVar", at: position)
        
        let formatted = ErrorFormatter.format(error)
        
        #expect(formatted.contains("SemanticError"))
        #expect(formatted.contains("Undeclared variable 'myVar'"))
        #expect(formatted.contains("line 3, column 7"))
        #expect(formatted.contains("Declare the variable before using it"))
    }

    @Test("Function Error Formatting")
    func testFunctionErrorFormatting() async throws {
        let position = SourcePosition(line: 8, column: 15)
        let error = SemanticError.incorrectArgumentCount(
            function: "calculateSum", 
            expected: 2, 
            actual: 3, 
            at: position
        )
        
        let formatted = ErrorFormatter.format(error)
        
        #expect(formatted.contains("SemanticError"))
        #expect(formatted.contains("Incorrect argument count for function 'calculateSum'"))
        #expect(formatted.contains("line 8, column 15"))
        #expect(formatted.contains("Expected: 2 arguments"))
        #expect(formatted.contains("Actual: 3 arguments"))
    }

    @Test("Control Flow Error Formatting")
    func testControlFlowErrorFormatting() async throws {
        let position = SourcePosition(line: 12, column: 5)
        let error = SemanticError.breakOutsideLoop(at: position)
        
        let formatted = ErrorFormatter.format(error)
        
        #expect(formatted.contains("SemanticError"))
        #expect(formatted.contains("Break statement outside loop"))
        #expect(formatted.contains("line 12, column 5"))
        #expect(formatted.contains("Use break only inside while or for loops"))
    }

    @Test("Array Error Formatting")
    func testArrayErrorFormatting() async throws {
        let position = SourcePosition(line: 6, column: 12)
        let error = SemanticError.arrayIndexTypeMismatch(
            expected: .integer, 
            actual: .string, 
            at: position
        )
        
        let formatted = ErrorFormatter.format(error)
        
        #expect(formatted.contains("SemanticError"))
        #expect(formatted.contains("Array index type mismatch"))
        #expect(formatted.contains("line 6, column 12"))
        #expect(formatted.contains("Expected type: integer"))
        #expect(formatted.contains("Actual type: string"))
    }

    @Test("Complex Type Error Formatting")
    func testComplexTypeErrorFormatting() async throws {
        let arrayType = FeType.array(elementType: .integer, dimensions: [10, 5])
        let recordType = FeType.record(name: "Person", fields: ["name": .string, "age": .integer])
        let position = SourcePosition(line: 15, column: 20)
        
        let error = SemanticError.incompatibleTypes(
            arrayType, 
            recordType, 
            operation: "assignment", 
            at: position
        )
        
        let formatted = ErrorFormatter.format(error)
        
        #expect(formatted.contains("SemanticError"))
        #expect(formatted.contains("Incompatible types for operation 'assignment'"))
        #expect(formatted.contains("line 15, column 20"))
        #expect(formatted.contains("array[10][5] of integer"))
        #expect(formatted.contains("record Person"))
    }

    @Test("Too Many Errors Formatting")
    func testTooManyErrorsFormatting() async throws {
        let error = SemanticError.tooManyErrors(count: 100)
        
        let formatted = ErrorFormatter.format(error)
        
        #expect(formatted.contains("SemanticError"))
        #expect(formatted.contains("Too many semantic errors (100)"))
        #expect(formatted.contains("Fix initial errors and re-run analysis"))
    }

    // MARK: - Context-Aware Formatting Tests

    @Test("Error Formatting with Source Context")
    func testErrorFormattingWithSourceContext() async throws {
        let sourceCode = """
        var x: integer;
        var y: string;
        x = y;  // Type mismatch here
        """
        
        let position = SourcePosition(line: 3, column: 1)
        let error = SemanticError.typeMismatch(expected: .integer, actual: .string, at: position)
        
        let formatted = ErrorFormatter.formatWithContext(error, input: sourceCode)
        
        #expect(formatted.contains("SemanticError"))
        #expect(formatted.contains("Type mismatch"))
        #expect(formatted.contains("Source context:"))
        #expect(formatted.contains("3: x = y;"))
        #expect(formatted.contains("^"))
    }

    @Test("Error Formatting with Symbol Table Context")
    func testErrorFormattingWithSymbolTableContext() async throws {
        let symbolTable = SymbolTable()
        let position = SourcePosition(line: 1, column: 1)
        
        // Add some similar variables to the symbol table
        symbolTable.declare(
            name: "userName", 
            type: .string, 
            kind: .variable, 
            at: SourcePosition(line: 1, column: 1)
        )
        symbolTable.declare(
            name: "userAge", 
            type: .integer, 
            kind: .variable, 
            at: SourcePosition(line: 2, column: 1)
        )
        
        let error = SemanticError.undeclaredVariable("usrName", at: position)
        
        let formatted = ErrorFormatter.formatWithContext(
            error, 
            input: "var x = usrName;", 
            symbolTable: symbolTable
        )
        
        #expect(formatted.contains("SemanticError"))
        #expect(formatted.contains("Undeclared variable 'usrName'"))
        // Should suggest similar variables
        #expect(formatted.contains("Similar variables:") || formatted.contains("userName"))
    }

    // MARK: - Specific Semantic Error Format Tests

    @Test("Function Declaration Error Formatting")
    func testFunctionDeclarationErrorFormatting() async throws {
        let position = SourcePosition(line: 10, column: 1)
        let error = SemanticError.functionAlreadyDeclared("calculateSum", at: position)
        
        let formatted = ErrorFormatter.format(error)
        
        #expect(formatted.contains("Function 'calculateSum' already declared"))
        #expect(formatted.contains("Use a different name or remove the duplicate declaration"))
    }

    @Test("Return Statement Error Formatting")
    func testReturnStatementErrorFormatting() async throws {
        let position = SourcePosition(line: 7, column: 5)
        let error = SemanticError.returnTypeMismatch(
            function: "getValue", 
            expected: .integer, 
            actual: .string, 
            at: position
        )
        
        let formatted = ErrorFormatter.format(error)
        
        #expect(formatted.contains("Return type mismatch in function 'getValue'"))
        #expect(formatted.contains("Expected type: integer"))
        #expect(formatted.contains("Actual type: string"))
    }

    @Test("Field Access Error Formatting")
    func testFieldAccessErrorFormatting() async throws {
        let position = SourcePosition(line: 9, column: 8)
        let error = SemanticError.undeclaredField(
            fieldName: "middleName", 
            recordType: "Person", 
            at: position
        )
        
        let formatted = ErrorFormatter.format(error)
        
        #expect(formatted.contains("Undeclared field 'middleName' in record type 'Person'"))
        #expect(formatted.contains("Check field name spelling or record type definition"))
    }

    @Test("Cyclic Dependency Error Formatting")
    func testCyclicDependencyErrorFormatting() async throws {
        let position = SourcePosition(line: 4, column: 1)
        let error = SemanticError.cyclicDependency(["a", "b", "c", "a"], at: position)
        
        let formatted = ErrorFormatter.format(error)
        
        #expect(formatted.contains("Cyclic dependency detected"))
        #expect(formatted.contains("Cycle: a -> b -> c -> a"))
    }

    // MARK: - Type Conversion Suggestions Tests

    @Test("Type Conversion Suggestions")
    func testTypeConversionSuggestions() async throws {
        let symbolTable = SymbolTable()
        
        // Test integer to string conversion suggestion
        let intToStringError = SemanticError.invalidTypeConversion(
            from: .integer, 
            to: .string, 
            at: SourcePosition(line: 1, column: 1)
        )
        
        let suggestion = symbolTable.suggestTypeConversion(from: .integer, to: .string)
        #expect(suggestion?.contains("string interpolation") == true)
        
        // Test real to integer conversion suggestion
        let realToIntError = SemanticError.invalidTypeConversion(
            from: .real, 
            to: .integer, 
            at: SourcePosition(line: 1, column: 1)
        )
        
        let intSuggestion = symbolTable.suggestTypeConversion(from: .real, to: .integer)
        #expect(intSuggestion?.contains("explicit casting") == true)
    }

    // MARK: - Similar Name Suggestions Tests

    @Test("Similar Variable Name Suggestions")
    func testSimilarVariableNameSuggestions() async throws {
        let symbolTable = SymbolTable()
        
        // Add variables with similar names
        symbolTable.declare(name: "userName", type: .string, kind: .variable, at: SourcePosition(line: 1, column: 1))
        symbolTable.declare(name: "userAge", type: .integer, kind: .variable, at: SourcePosition(line: 1, column: 1))
        symbolTable.declare(name: "userId", type: .integer, kind: .variable, at: SourcePosition(line: 1, column: 1))
        
        // Test finding similar names
        let similarNames = symbolTable.findSimilarNames(to: "usrName", type: .variable)
        #expect(!similarNames.isEmpty)
        #expect(similarNames.contains("userName"))
    }

    @Test("Similar Function Name Suggestions")
    func testSimilarFunctionNameSuggestions() async throws {
        let symbolTable = SymbolTable()
        
        // Add functions with similar names
        symbolTable.declare(
            name: "calculateSum", 
            type: .function(parameters: [.integer, .integer], returnType: .integer), 
            kind: .function, 
            at: SourcePosition(line: 1, column: 1)
        )
        symbolTable.declare(
            name: "calculateAvg", 
            type: .function(parameters: [.integer, .integer], returnType: .real), 
            kind: .function, 
            at: SourcePosition(line: 1, column: 1)
        )
        
        // Test finding similar function names
        let similarNames = symbolTable.findSimilarNames(to: "calcSum", type: .function)
        #expect(!similarNames.isEmpty)
        #expect(similarNames.contains("calculateSum"))
    }

    // MARK: - Integration Tests

    @Test("Multiple Error Types Formatting")
    func testMultipleErrorTypesFormatting() async throws {
        let errors: [SemanticError] = [
            .undeclaredVariable("x", at: SourcePosition(line: 1, column: 1)),
            .typeMismatch(expected: .integer, actual: .string, at: SourcePosition(line: 2, column: 5)),
            .incorrectArgumentCount(function: "test", expected: 1, actual: 2, at: SourcePosition(line: 3, column: 10)),
            .unreachableCode(at: SourcePosition(line: 4, column: 1))
        ]
        
        for error in errors {
            let formatted = ErrorFormatter.format(error)
            
            // All should be properly formatted semantic errors
            #expect(formatted.contains("SemanticError"))
            #expect(formatted.contains("line"))
            #expect(formatted.contains("column"))
        }
    }

    @Test("Error Message Component Integration")
    func testErrorMessageComponentIntegration() async throws {
        let position = SourcePosition(line: 5, column: 10)
        let error = SemanticError.argumentTypeMismatch(
            function: "testFunc", 
            paramIndex: 1, 
            expected: .integer, 
            actual: .boolean, 
            at: position
        )
        
        let formatted = ErrorFormatter.format(error)
        
        // Verify all components are present
        #expect(formatted.contains("SemanticError:")) // prefix
        #expect(formatted.contains("Argument type mismatch")) // message
        #expect(formatted.contains("line 5, column 10")) // position
        #expect(formatted.contains("Parameter: 2")) // parameter index (1-based)
        #expect(formatted.contains("Expected type: integer")) // expected type
        #expect(formatted.contains("Actual type: boolean")) // actual type
    }

    // MARK: - Performance Tests

    @Test("Error Formatting Performance")
    func testErrorFormattingPerformance() async throws {
        let errors = (1...1000).map { i in
            SemanticError.undeclaredVariable("var\(i)", at: SourcePosition(line: i, column: 1))
        }
        
        let startTime = Date()
        
        for error in errors {
            _ = ErrorFormatter.format(error)
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Should format 1000 errors in less than 1 second
        #expect(duration < 1.0)
    }

    // MARK: - Edge Cases

    @Test("Error Formatting - Missing position information")
    func testErrorFormattingMissingPosition() async throws {
        let error = SemanticError.tooManyErrors(count: 50)
        
        let formatted = ErrorFormatter.format(error)
        
        #expect(formatted.contains("SemanticError"))
        #expect(formatted.contains("Too many semantic errors"))
        // Should not crash when position is not available
        #expect(!formatted.contains("line"))
    }

    @Test("Error Formatting - Empty source context")
    func testErrorFormattingEmptySourceContext() async throws {
        let position = SourcePosition(line: 1, column: 1)
        let error = SemanticError.undeclaredVariable("x", at: position)
        
        let formatted = ErrorFormatter.formatWithContext(error, input: "")
        
        #expect(formatted.contains("SemanticError"))
        #expect(formatted.contains("Source context unavailable"))
    }

    @Test("Error Formatting - Invalid position in source")
    func testErrorFormattingInvalidPosition() async throws {
        let sourceCode = "var x: integer;"
        let position = SourcePosition(line: 10, column: 1) // Beyond source length
        let error = SemanticError.undeclaredVariable("y", at: position)
        
        let formatted = ErrorFormatter.formatWithContext(error, input: sourceCode)
        
        #expect(formatted.contains("SemanticError"))
        #expect(formatted.contains("Source context unavailable"))
    }
}