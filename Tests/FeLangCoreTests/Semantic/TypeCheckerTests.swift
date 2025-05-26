import Testing
import Foundation
@testable import FeLangCore

@Suite("Type Checker Tests")
struct TypeCheckerTests {
    
    // MARK: - Test Helpers
    
    private func createTypeChecker() -> TypeChecker {
        let symbolTable = SymbolTable()
        return TypeChecker(symbolTable: symbolTable)
    }
    
    private func createTypeCheckerWithSymbols() -> TypeChecker {
        let symbolTable = SymbolTable()
        
        // Add some test variables
        _ = symbolTable.declare(
            name: "intVar",
            type: .integer,
            kind: .variable,
            position: SourcePosition(line: 1, column: 1, offset: 0),
            isInitialized: true
        )
        
        _ = symbolTable.declare(
            name: "realVar",
            type: .real,
            kind: .variable,
            position: SourcePosition(line: 1, column: 1, offset: 0),
            isInitialized: true
        )
        
        _ = symbolTable.declare(
            name: "stringVar",
            type: .string,
            kind: .variable,
            position: SourcePosition(line: 1, column: 1, offset: 0),
            isInitialized: true
        )
        
        _ = symbolTable.declare(
            name: "boolVar",
            type: .boolean,
            kind: .variable,
            position: SourcePosition(line: 1, column: 1, offset: 0),
            isInitialized: true
        )
        
        _ = symbolTable.declare(
            name: "arrayVar",
            type: .array(elementType: .integer, dimensions: [10]),
            kind: .variable,
            position: SourcePosition(line: 1, column: 1, offset: 0),
            isInitialized: true
        )
        
        return TypeChecker(symbolTable: symbolTable)
    }
    
    // MARK: - Literal Type Checking Tests
    
    @Test("Integer literal type checking")
    func testIntegerLiteralTypeChecking() {
        let typeChecker = createTypeChecker()
        let expression = Expression.literal(.integer(42))
        
        let resultType = typeChecker.checkExpression(expression)
        
        #expect(resultType == .integer)
    }
    
    @Test("Real literal type checking")
    func testRealLiteralTypeChecking() {
        let typeChecker = createTypeChecker()
        let expression = Expression.literal(.real(3.14))
        
        let resultType = typeChecker.checkExpression(expression)
        
        #expect(resultType == .real)
    }
    
    @Test("String literal type checking")
    func testStringLiteralTypeChecking() {
        let typeChecker = createTypeChecker()
        let expression = Expression.literal(.string("hello"))
        
        let resultType = typeChecker.checkExpression(expression)
        
        #expect(resultType == .string)
    }
    
    @Test("Boolean literal type checking")
    func testBooleanLiteralTypeChecking() {
        let typeChecker = createTypeChecker()
        let expression = Expression.literal(.boolean(true))
        
        let resultType = typeChecker.checkExpression(expression)
        
        #expect(resultType == .boolean)
    }
    
    @Test("Character literal type checking")
    func testCharacterLiteralTypeChecking() {
        let typeChecker = createTypeChecker()
        let expression = Expression.literal(.character("A"))
        
        let resultType = typeChecker.checkExpression(expression)
        
        #expect(resultType == .character)
    }
    
    // MARK: - Identifier Type Checking Tests
    
    @Test("Valid identifier type checking")
    func testValidIdentifierTypeChecking() {
        let typeChecker = createTypeCheckerWithSymbols()
        let expression = Expression.identifier("intVar", SourcePosition(line: 1, column: 1, offset: 0))
        
        let resultType = typeChecker.checkExpression(expression)
        
        #expect(resultType == .integer)
    }
    
    @Test("Undeclared identifier type checking")
    func testUndeclaredIdentifierTypeChecking() {
        let typeChecker = createTypeCheckerWithSymbols()
        let expression = Expression.identifier("undeclaredVar", SourcePosition(line: 1, column: 1, offset: 0))
        
        let resultType = typeChecker.checkExpression(expression)
        
        #expect(resultType == .error)
        #expect(!typeChecker.getErrors().isEmpty)
        
        let hasUndeclaredError = typeChecker.getErrors().contains { error in
            if case .undeclaredVariable("undeclaredVar", at: _) = error {
                return true
            }
            return false
        }
        #expect(hasUndeclaredError)
    }
    
    // MARK: - Binary Expression Type Checking Tests
    
    @Test("Integer arithmetic type checking")
    func testIntegerArithmeticTypeChecking() {
        let typeChecker = createTypeChecker()
        
        let testCases: [(Expression.BinaryOperator, FeType)] = [
            (.add, .integer),
            (.subtract, .integer),
            (.multiply, .integer),
            (.divide, .real), // Division results in real
            (.modulo, .integer)
        ]
        
        for (op, expectedType) in testCases {
            let expression = Expression.binary(
                op,
                .literal(.integer(10)),
                .literal(.integer(5)),
                SourcePosition(line: 1, column: 1, offset: 0)
            )
            
            let resultType = typeChecker.checkExpression(expression)
            #expect(resultType == expectedType, "Operator \(op) should result in \(expectedType)")
        }
    }
    
    @Test("Mixed numeric arithmetic type checking")
    func testMixedNumericArithmeticTypeChecking() {
        let typeChecker = createTypeChecker()
        
        let expression = Expression.binary(
            .add,
            .literal(.integer(10)),
            .literal(.real(5.5)),
            SourcePosition(line: 1, column: 1, offset: 0)
        )
        
        let resultType = typeChecker.checkExpression(expression)
        #expect(resultType == .real)
    }
    
    @Test("String concatenation type checking")
    func testStringConcatenationTypeChecking() {
        let typeChecker = createTypeChecker()
        
        let expression = Expression.binary(
            .concatenate,
            .literal(.string("hello")),
            .literal(.string("world")),
            SourcePosition(line: 1, column: 1, offset: 0)
        )
        
        let resultType = typeChecker.checkExpression(expression)
        #expect(resultType == .string)
    }
    
    @Test("Comparison operations type checking")
    func testComparisonOperationsTypeChecking() {
        let typeChecker = createTypeChecker()
        
        let comparisonOps: [Expression.BinaryOperator] = [
            .equal, .notEqual, .lessThan, .lessThanOrEqual, .greaterThan, .greaterThanOrEqual
        ]
        
        for op in comparisonOps {
            let expression = Expression.binary(
                op,
                .literal(.integer(10)),
                .literal(.integer(5)),
                SourcePosition(line: 1, column: 1, offset: 0)
            )
            
            let resultType = typeChecker.checkExpression(expression)
            #expect(resultType == .boolean, "Comparison operator \(op) should result in boolean")
        }
    }
    
    @Test("Logical operations type checking")
    func testLogicalOperationsTypeChecking() {
        let typeChecker = createTypeChecker()
        
        let logicalOps: [Expression.BinaryOperator] = [.logicalAnd, .logicalOr]
        
        for op in logicalOps {
            let expression = Expression.binary(
                op,
                .literal(.boolean(true)),
                .literal(.boolean(false)),
                SourcePosition(line: 1, column: 1, offset: 0)
            )
            
            let resultType = typeChecker.checkExpression(expression)
            #expect(resultType == .boolean, "Logical operator \(op) should result in boolean")
        }
    }
    
    @Test("Invalid binary operation type checking")
    func testInvalidBinaryOperationTypeChecking() {
        let typeChecker = createTypeChecker()
        
        // Try to add string and integer
        let expression = Expression.binary(
            .add,
            .literal(.string("hello")),
            .literal(.integer(42)),
            SourcePosition(line: 1, column: 1, offset: 0)
        )
        
        let resultType = typeChecker.checkExpression(expression)
        #expect(resultType == .error)
        #expect(!typeChecker.getErrors().isEmpty)
    }
    
    // MARK: - Unary Expression Type Checking Tests
    
    @Test("Unary arithmetic operations type checking")
    func testUnaryArithmeticOperationsTypeChecking() {
        let typeChecker = createTypeChecker()
        
        let testCases: [(Expression.UnaryOperator, Expression.Literal, FeType)] = [
            (.plus, .integer(42), .integer),
            (.minus, .integer(42), .integer),
            (.plus, .real(3.14), .real),
            (.minus, .real(3.14), .real)
        ]
        
        for (op, literal, expectedType) in testCases {
            let expression = Expression.unary(
                op,
                .literal(literal),
                SourcePosition(line: 1, column: 1, offset: 0)
            )
            
            let resultType = typeChecker.checkExpression(expression)
            #expect(resultType == expectedType)
        }
    }
    
    @Test("Logical not operation type checking")
    func testLogicalNotOperationTypeChecking() {
        let typeChecker = createTypeChecker()
        
        let expression = Expression.unary(
            .logicalNot,
            .literal(.boolean(true)),
            SourcePosition(line: 1, column: 1, offset: 0)
        )
        
        let resultType = typeChecker.checkExpression(expression)
        #expect(resultType == .boolean)
    }
    
    @Test("Invalid unary operation type checking")
    func testInvalidUnaryOperationTypeChecking() {
        let typeChecker = createTypeChecker()
        
        // Try to negate a string
        let expression = Expression.unary(
            .minus,
            .literal(.string("hello")),
            SourcePosition(line: 1, column: 1, offset: 0)
        )
        
        let resultType = typeChecker.checkExpression(expression)
        #expect(resultType == .error)
        #expect(!typeChecker.getErrors().isEmpty)
    }
    
    // MARK: - Array Access Type Checking Tests
    
    @Test("Valid array access type checking")
    func testValidArrayAccessTypeChecking() {
        let typeChecker = createTypeCheckerWithSymbols()
        
        let expression = Expression.arrayAccess(
            array: .identifier("arrayVar", SourcePosition(line: 1, column: 1, offset: 0)),
            indices: [.literal(.integer(5))],
            position: SourcePosition(line: 1, column: 1, offset: 0)
        )
        
        let resultType = typeChecker.checkExpression(expression)
        #expect(resultType == .integer) // Array element type
    }
    
    @Test("Invalid array access type checking")
    func testInvalidArrayAccessTypeChecking() {
        let typeChecker = createTypeCheckerWithSymbols()
        
        // Try to access non-array variable as array
        let expression = Expression.arrayAccess(
            array: .identifier("intVar", SourcePosition(line: 1, column: 1, offset: 0)),
            indices: [.literal(.integer(0))],
            position: SourcePosition(line: 1, column: 1, offset: 0)
        )
        
        let resultType = typeChecker.checkExpression(expression)
        #expect(resultType == .error)
        #expect(!typeChecker.getErrors().isEmpty)
    }
    
    @Test("Array access with wrong index type")
    func testArrayAccessWithWrongIndexType() {
        let typeChecker = createTypeCheckerWithSymbols()
        
        let expression = Expression.arrayAccess(
            array: .identifier("arrayVar", SourcePosition(line: 1, column: 1, offset: 0)),
            indices: [.literal(.string("invalid"))],
            position: SourcePosition(line: 1, column: 1, offset: 0)
        )
        
        let resultType = typeChecker.checkExpression(expression)
        #expect(resultType == .integer) // Still returns element type but records error
        #expect(!typeChecker.getErrors().isEmpty)
        
        let hasIndexTypeError = typeChecker.getErrors().contains { error in
            if case .arrayIndexTypeMismatch(expected: .integer, actual: .string, at: _) = error {
                return true
            }
            return false
        }
        #expect(hasIndexTypeError)
    }
    
    // MARK: - Function Call Type Checking Tests
    
    @Test("Valid function call type checking")
    func testValidFunctionCallTypeChecking() {
        let symbolTable = SymbolTable()
        let typeChecker = TypeChecker(symbolTable: symbolTable)
        
        // Declare a test function
        _ = symbolTable.declare(
            name: "add",
            type: .function(parameters: [.integer, .integer], returnType: .integer),
            kind: .function,
            position: SourcePosition(line: 1, column: 1, offset: 0),
            isInitialized: true
        )
        
        let expression = Expression.functionCall(
            name: "add",
            arguments: [.literal(.integer(1)), .literal(.integer(2))],
            position: SourcePosition(line: 1, column: 1, offset: 0)
        )
        
        let resultType = typeChecker.checkExpression(expression)
        #expect(resultType == .integer)
    }
    
    @Test("Function call with wrong argument count")
    func testFunctionCallWithWrongArgumentCount() {
        let symbolTable = SymbolTable()
        let typeChecker = TypeChecker(symbolTable: symbolTable)
        
        // Declare a test function expecting 2 parameters
        _ = symbolTable.declare(
            name: "add",
            type: .function(parameters: [.integer, .integer], returnType: .integer),
            kind: .function,
            position: SourcePosition(line: 1, column: 1, offset: 0),
            isInitialized: true
        )
        
        // Call with only 1 argument
        let expression = Expression.functionCall(
            name: "add",
            arguments: [.literal(.integer(1))],
            position: SourcePosition(line: 1, column: 1, offset: 0)
        )
        
        let resultType = typeChecker.checkExpression(expression)
        #expect(resultType == .error)
        #expect(!typeChecker.getErrors().isEmpty)
        
        let hasArgCountError = typeChecker.getErrors().contains { error in
            if case .incorrectArgumentCount(function: "add", expected: 2, actual: 1, at: _) = error {
                return true
            }
            return false
        }
        #expect(hasArgCountError)
    }
    
    @Test("Function call with wrong argument types")
    func testFunctionCallWithWrongArgumentTypes() {
        let symbolTable = SymbolTable()
        let typeChecker = TypeChecker(symbolTable: symbolTable)
        
        // Declare a test function expecting integer parameters
        _ = symbolTable.declare(
            name: "add",
            type: .function(parameters: [.integer, .integer], returnType: .integer),
            kind: .function,
            position: SourcePosition(line: 1, column: 1, offset: 0),
            isInitialized: true
        )
        
        // Call with string argument
        let expression = Expression.functionCall(
            name: "add",
            arguments: [.literal(.string("hello")), .literal(.integer(2))],
            position: SourcePosition(line: 1, column: 1, offset: 0)
        )
        
        let resultType = typeChecker.checkExpression(expression)
        #expect(resultType == .error)
        #expect(!typeChecker.getErrors().isEmpty)
        
        let hasArgTypeError = typeChecker.getErrors().contains { error in
            if case .argumentTypeMismatch(function: "add", paramIndex: 0, expected: .integer, actual: .string, at: _) = error {
                return true
            }
            return false
        }
        #expect(hasArgTypeError)
    }
    
    @Test("Call to undeclared function")
    func testCallToUndeclaredFunction() {
        let typeChecker = createTypeChecker()
        
        let expression = Expression.functionCall(
            name: "undeclaredFunction",
            arguments: [],
            position: SourcePosition(line: 1, column: 1, offset: 0)
        )
        
        let resultType = typeChecker.checkExpression(expression)
        #expect(resultType == .error)
        #expect(!typeChecker.getErrors().isEmpty)
        
        let hasUndeclaredFuncError = typeChecker.getErrors().contains { error in
            if case .undeclaredFunction("undeclaredFunction", at: _) = error {
                return true
            }
            return false
        }
        #expect(hasUndeclaredFuncError)
    }
    
    // MARK: - Type Compatibility Tests
    
    @Test("Type compatibility checking")
    func testTypeCompatibilityChecking() {
        let typeChecker = createTypeChecker()
        
        let compatiblePairs: [(FeType, FeType)] = [
            (.integer, .integer),
            (.real, .real),
            (.integer, .real),
            (.real, .integer),
            (.string, .string),
            (.boolean, .boolean),
            (.error, .integer), // Error type is compatible with everything
            (.unknown, .string) // Unknown type is compatible during inference
        ]
        
        for (type1, type2) in compatiblePairs {
            #expect(typeChecker.areCompatible(type1, type2), "\(type1) should be compatible with \(type2)")
        }
        
        let incompatiblePairs: [(FeType, FeType)] = [
            (.integer, .string),
            (.boolean, .integer),
            (.string, .boolean)
        ]
        
        for (type1, type2) in incompatiblePairs {
            #expect(!typeChecker.areCompatible(type1, type2), "\(type1) should not be compatible with \(type2)")
        }
    }
    
    @Test("Assignment compatibility checking")
    func testAssignmentCompatibilityChecking() {
        let typeChecker = createTypeChecker()
        
        let validAssignments: [(FeType, FeType)] = [
            (.integer, .integer),
            (.integer, .real), // Can assign integer to real
            (.real, .real),
            (.string, .string),
            (.boolean, .boolean)
        ]
        
        for (valueType, targetType) in validAssignments {
            #expect(typeChecker.canAssign(valueType: valueType, to: targetType), 
                   "Should be able to assign \(valueType) to \(targetType)")
        }
        
        let invalidAssignments: [(FeType, FeType)] = [
            (.real, .integer), // Cannot assign real to integer
            (.string, .integer),
            (.boolean, .string)
        ]
        
        for (valueType, targetType) in invalidAssignments {
            #expect(!typeChecker.canAssign(valueType: valueType, to: targetType), 
                   "Should not be able to assign \(valueType) to \(targetType)")
        }
    }
    
    // MARK: - Error Collection Tests
    
    @Test("Error collection and clearing")
    func testErrorCollectionAndClearing() {
        let typeChecker = createTypeChecker()
        
        // Generate some errors
        _ = typeChecker.checkExpression(.identifier("undeclared1", SourcePosition(line: 1, column: 1, offset: 0)))
        _ = typeChecker.checkExpression(.identifier("undeclared2", SourcePosition(line: 2, column: 1, offset: 10)))
        
        #expect(typeChecker.getErrors().count == 2)
        
        typeChecker.clearErrors()
        #expect(typeChecker.getErrors().isEmpty)
    }
}