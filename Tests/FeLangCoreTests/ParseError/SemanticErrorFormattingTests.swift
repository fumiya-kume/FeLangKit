import Testing
@testable import FeLangCore

/// Tests for semantic error integration with the ErrorFormatter infrastructure.
/// This test file verifies that semantic errors are properly formatted using the 
/// component-based error message building system.
@Suite("Semantic Error Formatting Tests")
struct SemanticErrorFormattingTests {

    // MARK: - Helper Methods

    private static func createSourcePosition(line: Int, column: Int) -> SourcePosition {
        return SourcePosition(line: line, column: column, offset: 0)
    }

    // MARK: - Type Error Formatting Tests

    @Test("Type Mismatch Error Formatting")
    func testTypeMismatchFormatting() async throws {
        let position = Self.createSourcePosition(line: 1, column: 19)
        let error = SemanticError.typeMismatch(expected: .integer, actual: .string, at: position)

        let formatted = ErrorFormatter.format(error)

        let expected = """
        SemanticError: Type mismatch
          at line 1, column 19
          Expected type: integer
          Actual type: string
          Suggestion: Check variable declaration
          Suggestion: Use explicit type conversion
        """

        #expect(formatted == expected)
    }

    @Test("Incompatible Types Error Formatting")
    func testIncompatibleTypesFormatting() async throws {
        let position = Self.createSourcePosition(line: 1, column: 17)
        let error = SemanticError.incompatibleTypes(.integer, .string, operation: "+", at: position)

        let formatted = ErrorFormatter.format(error)

        let expected = """
        SemanticError: Incompatible types for operation '+'
          at line 1, column 17
          Left operand type: integer
          Right operand type: string
          Suggestion: Ensure both operands have compatible types
          Suggestion: Use type conversion if needed
        """

        #expect(formatted == expected)
    }

    @Test("Unknown Type Error Formatting")
    func testUnknownTypeFormatting() async throws {
        let position = Self.createSourcePosition(line: 1, column: 8)
        let error = SemanticError.unknownType("MyCustomType", at: position)

        let formatted = ErrorFormatter.format(error)

        let expected = """
        SemanticError: Unknown type 'MyCustomType'
          at line 1, column 8
          Suggestion: Check spelling of type name
          Suggestion: Ensure type is declared
          Suggestion: Use built-in types: integer, real, string, boolean
        """

        #expect(formatted == expected)
    }

    @Test("Invalid Type Conversion Error Formatting")
    func testInvalidTypeConversionFormatting() async throws {
        let position = Self.createSourcePosition(line: 1, column: 19)
        let error = SemanticError.invalidTypeConversion(from: .string, to: .integer, at: position)

        let formatted = ErrorFormatter.format(error)

        let expected = """
        SemanticError: Invalid type conversion
          at line 1, column 19
          From: string
          To: integer
          Suggestion: Use compatible types
          Suggestion: Check conversion is supported
        """

        #expect(formatted == expected)
    }

    // MARK: - Variable Error Formatting Tests

    @Test("Undeclared Variable Error Formatting")
    func testUndeclaredVariableFormatting() async throws {
        let position = Self.createSourcePosition(line: 1, column: 10)
        let error = SemanticError.undeclaredVariable("undeclaredVar", at: position)

        let formatted = ErrorFormatter.format(error)

        let expected = """
        SemanticError: Undeclared variable 'undeclaredVar'
          at line 1, column 10
          Suggestion: Declare variable before use
          Suggestion: Check variable name spelling
          Suggestion: Ensure variable is in scope
        """

        #expect(formatted == expected)
    }

    @Test("Variable Already Declared Error Formatting")
    func testVariableAlreadyDeclaredFormatting() async throws {
        let position = Self.createSourcePosition(line: 2, column: 5)
        let error = SemanticError.variableAlreadyDeclared("x", at: position)

        let formatted = ErrorFormatter.format(error)

        let expected = """
        SemanticError: Variable 'x' already declared
          at line 2, column 5
          Suggestion: Use different variable name
          Suggestion: Remove duplicate declaration
          Suggestion: Check variable scope
        """

        #expect(formatted == expected)
    }

    @Test("Variable Not Initialized Error Formatting")
    func testVariableNotInitializedFormatting() async throws {
        let position = Self.createSourcePosition(line: 2, column: 10)
        let error = SemanticError.variableNotInitialized("x", at: position)

        let formatted = ErrorFormatter.format(error)

        let expected = """
        SemanticError: Variable 'x' used before initialization
          at line 2, column 10
          Suggestion: Initialize variable before use
          Suggestion: Assign value to variable
          Suggestion: Check initialization order
        """

        #expect(formatted == expected)
    }

    @Test("Constant Reassignment Error Formatting")
    func testConstantReassignmentFormatting() async throws {
        let position = Self.createSourcePosition(line: 2, column: 1)
        let error = SemanticError.constantReassignment("PI", at: position)

        let formatted = ErrorFormatter.format(error)

        let expected = """
        SemanticError: Cannot reassign constant 'PI'
          at line 2, column 1
          Suggestion: Use variable instead of constant
          Suggestion: Initialize constant with final value
          Suggestion: Create new variable for changed value
        """

        #expect(formatted == expected)
    }

    @Test("Invalid Assignment Target Error Formatting")
    func testInvalidAssignmentTargetFormatting() async throws {
        let position = Self.createSourcePosition(line: 1, column: 7)
        let error = SemanticError.invalidAssignmentTarget(at: position)

        let formatted = ErrorFormatter.format(error)

        let expected = """
        SemanticError: Invalid assignment target
          at line 1, column 7
          Suggestion: Assign to variable, not expression
          Suggestion: Use valid lvalue for assignment
        """

        #expect(formatted == expected)
    }

    // MARK: - Function Error Formatting Tests

    @Test("Undeclared Function Error Formatting")
    func testUndeclaredFunctionFormatting() async throws {
        let position = Self.createSourcePosition(line: 1, column: 15)
        let error = SemanticError.undeclaredFunction("unknownFunction", at: position)

        let formatted = ErrorFormatter.format(error)

        let expected = """
        SemanticError: Undeclared function 'unknownFunction'
          at line 1, column 15
          Suggestion: Declare function before use
          Suggestion: Check function name spelling
          Suggestion: Import required module
        """

        #expect(formatted == expected)
    }

    @Test("Function Already Declared Error Formatting")
    func testFunctionAlreadyDeclaredFormatting() async throws {
        let position = Self.createSourcePosition(line: 2, column: 10)
        let error = SemanticError.functionAlreadyDeclared("add", at: position)

        let formatted = ErrorFormatter.format(error)

        let expected = """
        SemanticError: Function 'add' already declared
          at line 2, column 10
          Suggestion: Use different function name
          Suggestion: Remove duplicate declaration
          Suggestion: Check function overloading rules
        """

        #expect(formatted == expected)
    }

    @Test("Incorrect Argument Count Error Formatting")
    func testIncorrectArgumentCountFormatting() async throws {
        let position = Self.createSourcePosition(line: 2, column: 15)
        let error = SemanticError.incorrectArgumentCount(function: "multiply", expected: 2, actual: 1, at: position)

        let formatted = ErrorFormatter.format(error)

        let expected = """
        SemanticError: Incorrect argument count for function 'multiply'
          at line 2, column 15
          Expected: 2 arguments
          Actual: 1 arguments
          Suggestion: Provide correct number of arguments
          Suggestion: Check function signature
        """

        #expect(formatted == expected)
    }

    @Test("Argument Type Mismatch Error Formatting")
    func testArgumentTypeMismatchFormatting() async throws {
        let position = Self.createSourcePosition(line: 2, column: 22)
        let error = SemanticError.argumentTypeMismatch(function: "greet", paramIndex: 0, expected: .string, actual: .integer, at: position)

        let formatted = ErrorFormatter.format(error)

        let expected = """
        SemanticError: Argument type mismatch for function 'greet'
          at line 2, column 22
          Parameter 1: expected string, got integer
          Suggestion: Use correct argument type
          Suggestion: Apply type conversion
          Suggestion: Check function parameters
        """

        #expect(formatted == expected)
    }

    @Test("Missing Return Statement Error Formatting")
    func testMissingReturnStatementFormatting() async throws {
        let position = Self.createSourcePosition(line: 4, column: 1)
        let error = SemanticError.missingReturnStatement(function: "calculate", at: position)

        let formatted = ErrorFormatter.format(error)

        let expected = """
        SemanticError: Missing return statement in function 'calculate'
          at line 4, column 1
          Suggestion: Add return statement
          Suggestion: Ensure all code paths return value
          Suggestion: Use procedure if no return needed
        """

        #expect(formatted == expected)
    }

    @Test("Return Type Mismatch Error Formatting")
    func testReturnTypeMismatchFormatting() async throws {
        let position = Self.createSourcePosition(line: 3, column: 3)
        let error = SemanticError.returnTypeMismatch(function: "getNumber", expected: .integer, actual: .string, at: position)

        let formatted = ErrorFormatter.format(error)

        let expected = """
        SemanticError: Return type mismatch in function 'getNumber'
          at line 3, column 3
          Expected: integer
          Actual: string
          Suggestion: Return correct type
          Suggestion: Update function signature
          Suggestion: Apply type conversion
        """

        #expect(formatted == expected)
    }

    @Test("Void Function Returns Value Error Formatting")
    func testVoidFunctionReturnsValueFormatting() async throws {
        let position = Self.createSourcePosition(line: 3, column: 3)
        let error = SemanticError.voidFunctionReturnsValue(function: "doSomething", at: position)

        let formatted = ErrorFormatter.format(error)

        let expected = """
        SemanticError: Void function 'doSomething' cannot return value
          at line 3, column 3
          Suggestion: Remove return value
          Suggestion: Change function to return type
          Suggestion: Use procedure syntax
        """

        #expect(formatted == expected)
    }

    // MARK: - Control Flow Error Formatting Tests

    @Test("Unreachable Code Error Formatting")
    func testUnreachableCodeFormatting() async throws {
        let position = Self.createSourcePosition(line: 4, column: 3)
        let error = SemanticError.unreachableCode(at: position)

        let formatted = ErrorFormatter.format(error)

        let expected = """
        SemanticError: Unreachable code detected
          at line 4, column 3
          Suggestion: Remove unreachable code
          Suggestion: Fix control flow logic
          Suggestion: Check conditional statements
        """

        #expect(formatted == expected)
    }

    @Test("Break Outside Loop Error Formatting")
    func testBreakOutsideLoopFormatting() async throws {
        let position = Self.createSourcePosition(line: 3, column: 3)
        let error = SemanticError.breakOutsideLoop(at: position)

        let formatted = ErrorFormatter.format(error)

        let expected = """
        SemanticError: Break statement outside loop
          at line 3, column 3
          Suggestion: Use break only inside loops
          Suggestion: Remove break statement
          Suggestion: Use return for functions
        """

        #expect(formatted == expected)
    }

    @Test("Return Outside Function Error Formatting")
    func testReturnOutsideFunctionFormatting() async throws {
        let position = Self.createSourcePosition(line: 2, column: 1)
        let error = SemanticError.returnOutsideFunction(at: position)

        let formatted = ErrorFormatter.format(error)

        let expected = """
        SemanticError: Return statement outside function
          at line 2, column 1
          Suggestion: Use return only inside functions
          Suggestion: Remove return statement
          Suggestion: Declare function wrapper
        """

        #expect(formatted == expected)
    }

    // MARK: - Array Error Formatting Tests

    @Test("Invalid Array Access Error Formatting")
    func testInvalidArrayAccessFormatting() async throws {
        let position = Self.createSourcePosition(line: 2, column: 16)
        let error = SemanticError.invalidArrayAccess(at: position)

        let formatted = ErrorFormatter.format(error)

        let expected = """
        SemanticError: Invalid array access
          at line 2, column 16
          Suggestion: Check array variable exists
          Suggestion: Use valid index expression
          Suggestion: Ensure array is properly declared
        """

        #expect(formatted == expected)
    }

    @Test("Array Index Type Mismatch Error Formatting")
    func testArrayIndexTypeMismatchFormatting() async throws {
        let position = Self.createSourcePosition(line: 2, column: 16)
        let error = SemanticError.arrayIndexTypeMismatch(expected: .integer, actual: .string, at: position)

        let formatted = ErrorFormatter.format(error)

        let expected = """
        SemanticError: Array index type mismatch
          at line 2, column 16
          Expected: integer
          Actual: string
          Suggestion: Use integer index
          Suggestion: Convert index to correct type
        """

        #expect(formatted == expected)
    }

    @Test("Invalid Array Dimension Error Formatting")
    func testInvalidArrayDimensionFormatting() async throws {
        let position = Self.createSourcePosition(line: 1, column: 13)
        let error = SemanticError.invalidArrayDimension(at: position)

        let formatted = ErrorFormatter.format(error)

        let expected = """
        SemanticError: Invalid array dimension
          at line 1, column 13
          Suggestion: Use valid dimension specification
          Suggestion: Check array declaration syntax
        """

        #expect(formatted == expected)
    }

    // MARK: - Record Error Formatting Tests

    @Test("Undeclared Field Error Formatting")
    func testUndeclaredFieldFormatting() async throws {
        let position = Self.createSourcePosition(line: 3, column: 12)
        let error = SemanticError.undeclaredField(fieldName: "age", recordType: "Person", at: position)

        let formatted = ErrorFormatter.format(error)

        let expected = """
        SemanticError: Undeclared field 'age' in record 'Person'
          at line 3, column 12
          Suggestion: Check field name spelling
          Suggestion: Declare field in record type
          Suggestion: Use existing field
        """

        #expect(formatted == expected)
    }

    @Test("Invalid Field Access Error Formatting")
    func testInvalidFieldAccessFormatting() async throws {
        let position = Self.createSourcePosition(line: 2, column: 14)
        let error = SemanticError.invalidFieldAccess(at: position)

        let formatted = ErrorFormatter.format(error)

        let expected = """
        SemanticError: Invalid field access
          at line 2, column 14
          Suggestion: Access field on record variable
          Suggestion: Check record type has field
          Suggestion: Use dot notation
        """

        #expect(formatted == expected)
    }

    // MARK: - Analysis Limitation Error Formatting Tests

    @Test("Cyclic Dependency Error Formatting")
    func testCyclicDependencyFormatting() async throws {
        let position = Self.createSourcePosition(line: 3, column: 10)
        let error = SemanticError.cyclicDependency(["a", "b", "c", "a"], at: position)

        let formatted = ErrorFormatter.format(error)

        let expected = """
        SemanticError: Cyclic dependency detected
          at line 3, column 10
          Dependency chain: a -> b -> c -> a
          Suggestion: Break circular dependency
          Suggestion: Reorder declarations
          Suggestion: Use forward declarations
        """

        #expect(formatted == expected)
    }

    @Test("Analysis Depth Exceeded Error Formatting")
    func testAnalysisDepthExceededFormatting() async throws {
        let position = Self.createSourcePosition(line: 1, column: 13)
        let error = SemanticError.analysisDepthExceeded(at: position)

        let formatted = ErrorFormatter.format(error)

        let expected = """
        SemanticError: Analysis depth exceeded
          at line 1, column 13
          Suggestion: Simplify expression structure
          Suggestion: Reduce nesting depth
          Suggestion: Break complex expressions
        """

        #expect(formatted == expected)
    }

    @Test("Too Many Errors Error Formatting")
    func testTooManyErrorsFormatting() async throws {
        let error = SemanticError.tooManyErrors(count: 100)

        let formatted = ErrorFormatter.format(error)

        let expected = """
        SemanticError: Too many semantic errors (100), stopping analysis
          Fix existing errors before continuing
        """

        #expect(formatted == expected)
    }

    // MARK: - Integration Tests

    @Test("SemanticErrorReporter with ErrorFormatter Integration")
    func testSemanticErrorReporterWithFormatterIntegration() async throws {
        let reporter = SemanticErrorReporter()
        let symbolTable = SymbolTable()

        let position1 = Self.createSourcePosition(line: 1, column: 10)
        let position2 = Self.createSourcePosition(line: 2, column: 5)

        let error1 = SemanticError.undeclaredVariable("x", at: position1)
        let error2 = SemanticError.typeMismatch(expected: .integer, actual: .string, at: position2)

        reporter.collect(error1)
        reporter.collect(error2)

        let result = reporter.finalize(with: symbolTable)

        #expect(result.errors.count == 2)
        #expect(!result.isSuccessful)

        // Test that each error can be properly formatted
        let formatted1 = ErrorFormatter.format(result.errors[0])
        let formatted2 = ErrorFormatter.format(result.errors[1])

        #expect(formatted1.contains("SemanticError: Undeclared variable 'x'"))
        #expect(formatted1.contains("at line 1, column 10"))

        #expect(formatted2.contains("SemanticError: Type mismatch"))
        #expect(formatted2.contains("at line 2, column 5"))
    }

    @Test("Error Formatting with Context")
    func testErrorFormattingWithContext() async throws {
        let position = Self.createSourcePosition(line: 1, column: 19)
        let error = SemanticError.typeMismatch(expected: .integer, actual: .string, at: position)
        let input = "var x: integer := \"hello\""

        let formatted = ErrorFormatter.formatWithContext(error, input: input)

        #expect(formatted.contains("SemanticError: Type mismatch"))
        #expect(formatted.contains("at line 1, column 19"))
        #expect(formatted.contains("Source context:"))
        #expect(formatted.contains("var x: integer := \"hello\""))
    }
}
