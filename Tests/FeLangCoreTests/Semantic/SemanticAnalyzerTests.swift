import Testing
import Foundation
@testable import FeLangCore

@Suite("Semantic Analyzer Tests")
struct SemanticAnalyzerTests {
    
    // MARK: - Test Helpers
    
    private func createAnalyzer() -> SemanticAnalyzer {
        return SemanticAnalyzer()
    }
    
    private func createStatement(
        _ type: Statement
    ) -> Statement {
        return type
    }
    
    // MARK: - Variable Declaration Tests
    
    @Test("Variable declaration with explicit type")
    func testVariableDeclarationWithExplicitType() {
        let analyzer = createAnalyzer()
        
        let statements = [
            createStatement(.variableDeclaration(
                name: "x",
                dataType: .integer,
                initialValue: .literal(.integer(42)),
                position: SourcePosition(line: 1, column: 1, offset: 0)
            ))
        ]
        
        let result = analyzer.analyze(statements: statements)
        
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
        
        // Check symbol table contains the variable
        let symbol = result.symbolTable.lookup("x")
        #expect(symbol != nil)
        #expect(symbol?.type == .integer)
        #expect(symbol?.kind == .variable)
        #expect(symbol?.isInitialized == true)
    }
    
    @Test("Variable declaration with type inference")
    func testVariableDeclarationWithTypeInference() {
        let analyzer = createAnalyzer()
        
        let statements = [
            createStatement(.variableDeclaration(
                name: "message",
                dataType: nil,
                initialValue: .literal(.string("hello")),
                position: SourcePosition(line: 1, column: 1, offset: 0)
            ))
        ]
        
        let result = analyzer.analyze(statements: statements)
        
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
        
        let symbol = result.symbolTable.lookup("message")
        #expect(symbol?.type == .string)
    }
    
    @Test("Variable declaration type mismatch")
    func testVariableDeclarationTypeMismatch() {
        let analyzer = createAnalyzer()
        
        let statements = [
            createStatement(.variableDeclaration(
                name: "x",
                dataType: .integer,
                initialValue: .literal(.string("hello")),
                position: SourcePosition(line: 1, column: 1, offset: 0)
            ))
        ]
        
        let result = analyzer.analyze(statements: statements)
        
        #expect(!result.isSuccessful)
        #expect(result.hasErrors)
        
        let hasTypeMismatchError = result.errors.contains { error in
            if case .typeMismatch(expected: .integer, actual: .string, at: _) = error {
                return true
            }
            return false
        }
        #expect(hasTypeMismatchError)
    }
    
    @Test("Duplicate variable declaration")
    func testDuplicateVariableDeclaration() {
        let analyzer = createAnalyzer()
        
        let statements = [
            createStatement(.variableDeclaration(
                name: "x",
                dataType: .integer,
                initialValue: .literal(.integer(1)),
                position: SourcePosition(line: 1, column: 1, offset: 0)
            )),
            createStatement(.variableDeclaration(
                name: "x",
                dataType: .real,
                initialValue: .literal(.real(2.0)),
                position: SourcePosition(line: 2, column: 1, offset: 10)
            ))
        ]
        
        let result = analyzer.analyze(statements: statements)
        
        #expect(!result.isSuccessful)
        #expect(result.hasErrors)
        
        let hasAlreadyDeclaredError = result.errors.contains { error in
            if case .variableAlreadyDeclared("x", at: _) = error {
                return true
            }
            return false
        }
        #expect(hasAlreadyDeclaredError)
    }
    
    // MARK: - Constant Declaration Tests
    
    @Test("Constant declaration")
    func testConstantDeclaration() {
        let analyzer = createAnalyzer()
        
        let statements = [
            createStatement(.constantDeclaration(
                name: "PI",
                dataType: .real,
                value: .literal(.real(3.14159)),
                position: SourcePosition(line: 1, column: 1, offset: 0)
            ))
        ]
        
        let result = analyzer.analyze(statements: statements)
        
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
        
        let symbol = result.symbolTable.lookup("PI")
        #expect(symbol?.type == .real)
        #expect(symbol?.kind == .constant)
        #expect(symbol?.isInitialized == true)
    }
    
    @Test("Constant reassignment error")
    func testConstantReassignmentError() {
        let analyzer = createAnalyzer()
        
        let statements = [
            createStatement(.constantDeclaration(
                name: "PI",
                dataType: .real,
                value: .literal(.real(3.14159)),
                position: SourcePosition(line: 1, column: 1, offset: 0)
            )),
            createStatement(.assignment(
                target: .variable("PI"),
                value: .literal(.real(3.14)),
                position: SourcePosition(line: 2, column: 1, offset: 20)
            ))
        ]
        
        let result = analyzer.analyze(statements: statements)
        
        #expect(!result.isSuccessful)
        #expect(result.hasErrors)
        
        let hasConstantReassignmentError = result.errors.contains { error in
            if case .constantReassignment("PI", at: _) = error {
                return true
            }
            return false
        }
        #expect(hasConstantReassignmentError)
    }
    
    // MARK: - Function Declaration Tests
    
    @Test("Function declaration with return type")
    func testFunctionDeclarationWithReturnType() {
        let analyzer = createAnalyzer()
        
        let parameters = [
            Statement.Parameter(name: "x", type: .integer),
            Statement.Parameter(name: "y", type: .integer)
        ]
        
        let body = [
            createStatement(.returnStatement(
                value: .binary(
                    .add,
                    .identifier("x", SourcePosition(line: 2, column: 12, offset: 30)),
                    .identifier("y", SourcePosition(line: 2, column: 16, offset: 34)),
                    SourcePosition(line: 2, column: 14, offset: 32)
                ),
                position: SourcePosition(line: 2, column: 5, offset: 25)
            ))
        ]
        
        let statements = [
            createStatement(.functionDeclaration(
                name: "add",
                parameters: parameters,
                returnType: .integer,
                body: body,
                position: SourcePosition(line: 1, column: 1, offset: 0)
            ))
        ]
        
        let result = analyzer.analyze(statements: statements)
        
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
        
        let symbol = result.symbolTable.lookup("add")
        #expect(symbol?.kind == .function)
        
        if case .function(let params, let returnType) = symbol?.type {
            #expect(params == [.integer, .integer])
            #expect(returnType == .integer)
        } else {
            #expect(Bool(false), "Expected function type")
        }
    }
    
    @Test("Function missing return statement")
    func testFunctionMissingReturnStatement() {
        let analyzer = createAnalyzer()
        
        let parameters = [Statement.Parameter(name: "x", type: .integer)]
        let body = [
            createStatement(.expressionStatement(
                .identifier("x", SourcePosition(line: 2, column: 5, offset: 20)),
                SourcePosition(line: 2, column: 5, offset: 20)
            ))
        ]
        
        let statements = [
            createStatement(.functionDeclaration(
                name: "identity",
                parameters: parameters,
                returnType: .integer,
                body: body,
                position: SourcePosition(line: 1, column: 1, offset: 0)
            ))
        ]
        
        let result = analyzer.analyze(statements: statements)
        
        #expect(!result.isSuccessful)
        #expect(result.hasErrors)
        
        let hasMissingReturnError = result.errors.contains { error in
            if case .missingReturnStatement(function: "identity", at: _) = error {
                return true
            }
            return false
        }
        #expect(hasMissingReturnError)
    }
    
    // MARK: - Assignment Tests
    
    @Test("Valid variable assignment")
    func testValidVariableAssignment() {
        let analyzer = createAnalyzer()
        
        let statements = [
            createStatement(.variableDeclaration(
                name: "x",
                dataType: .integer,
                initialValue: nil,
                position: SourcePosition(line: 1, column: 1, offset: 0)
            )),
            createStatement(.assignment(
                target: .variable("x"),
                value: .literal(.integer(42)),
                position: SourcePosition(line: 2, column: 1, offset: 15)
            ))
        ]
        
        let result = analyzer.analyze(statements: statements)
        
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
    }
    
    @Test("Assignment to undeclared variable")
    func testAssignmentToUndeclaredVariable() {
        let analyzer = createAnalyzer()
        
        let statements = [
            createStatement(.assignment(
                target: .variable("undeclaredVar"),
                value: .literal(.integer(42)),
                position: SourcePosition(line: 1, column: 1, offset: 0)
            ))
        ]
        
        let result = analyzer.analyze(statements: statements)
        
        #expect(!result.isSuccessful)
        #expect(result.hasErrors)
        
        let hasUndeclaredVarError = result.errors.contains { error in
            if case .undeclaredVariable("undeclaredVar", at: _) = error {
                return true
            }
            return false
        }
        #expect(hasUndeclaredVarError)
    }
    
    @Test("Assignment type mismatch")
    func testAssignmentTypeMismatch() {
        let analyzer = createAnalyzer()
        
        let statements = [
            createStatement(.variableDeclaration(
                name: "x",
                dataType: .integer,
                initialValue: .literal(.integer(0)),
                position: SourcePosition(line: 1, column: 1, offset: 0)
            )),
            createStatement(.assignment(
                target: .variable("x"),
                value: .literal(.string("hello")),
                position: SourcePosition(line: 2, column: 1, offset: 20)
            ))
        ]
        
        let result = analyzer.analyze(statements: statements)
        
        #expect(!result.isSuccessful)
        #expect(result.hasErrors)
        
        let hasTypeMismatchError = result.errors.contains { error in
            if case .typeMismatch(expected: .integer, actual: .string, at: _) = error {
                return true
            }
            return false
        }
        #expect(hasTypeMismatchError)
    }
    
    // MARK: - Control Flow Tests
    
    @Test("If statement with boolean condition")
    func testIfStatementWithBooleanCondition() {
        let analyzer = createAnalyzer()
        
        let condition = Expression.binary(
            .equal,
            .literal(.integer(1)),
            .literal(.integer(1)),
            SourcePosition(line: 1, column: 4, offset: 3)
        )
        
        let thenBranch = [
            createStatement(.expressionStatement(
                .literal(.integer(42)),
                SourcePosition(line: 2, column: 5, offset: 15)
            ))
        ]
        
        let statements = [
            createStatement(.ifStatement(
                condition: condition,
                thenBranch: thenBranch,
                elseBranch: nil,
                position: SourcePosition(line: 1, column: 1, offset: 0)
            ))
        ]
        
        let result = analyzer.analyze(statements: statements)
        
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
    }
    
    @Test("If statement with non-boolean condition")
    func testIfStatementWithNonBooleanCondition() {
        let analyzer = createAnalyzer()
        
        let condition = Expression.literal(.integer(42))
        
        let thenBranch = [
            createStatement(.expressionStatement(
                .literal(.integer(1)),
                SourcePosition(line: 2, column: 5, offset: 15)
            ))
        ]
        
        let statements = [
            createStatement(.ifStatement(
                condition: condition,
                thenBranch: thenBranch,
                elseBranch: nil,
                position: SourcePosition(line: 1, column: 1, offset: 0)
            ))
        ]
        
        let result = analyzer.analyze(statements: statements)
        
        #expect(!result.isSuccessful)
        #expect(result.hasErrors)
        
        let hasTypeMismatchError = result.errors.contains { error in
            if case .typeMismatch(expected: .boolean, actual: .integer, at: _) = error {
                return true
            }
            return false
        }
        #expect(hasTypeMismatchError)
    }
    
    // MARK: - Scope Tests
    
    @Test("Variable scope isolation")
    func testVariableScopeIsolation() {
        let analyzer = createAnalyzer()
        
        let innerBlock = [
            createStatement(.variableDeclaration(
                name: "innerVar",
                dataType: .integer,
                initialValue: .literal(.integer(1)),
                position: SourcePosition(line: 2, column: 5, offset: 15)
            ))
        ]
        
        let statements = [
            createStatement(.variableDeclaration(
                name: "outerVar",
                dataType: .integer,
                initialValue: .literal(.integer(0)),
                position: SourcePosition(line: 1, column: 1, offset: 0)
            )),
            createStatement(.block(innerBlock, SourcePosition(line: 2, column: 1, offset: 10))),
            createStatement(.assignment(
                target: .variable("innerVar"),
                value: .literal(.integer(2)),
                position: SourcePosition(line: 4, column: 1, offset: 40)
            ))
        ]
        
        let result = analyzer.analyze(statements: statements)
        
        #expect(!result.isSuccessful)
        #expect(result.hasErrors)
        
        // Should get undeclared variable error for innerVar outside its scope
        let hasUndeclaredVarError = result.errors.contains { error in
            if case .undeclaredVariable("innerVar", at: _) = error {
                return true
            }
            return false
        }
        #expect(hasUndeclaredVarError)
    }
    
    // MARK: - Error Limit Tests
    
    @Test("Error limit enforcement")
    func testErrorLimitEnforcement() {
        let options = SemanticAnalyzer.AnalysisOptions(maxErrors: 2)
        let analyzer = SemanticAnalyzer(options: options)
        
        let statements = [
            createStatement(.assignment(
                target: .variable("undeclared1"),
                value: .literal(.integer(1)),
                position: SourcePosition(line: 1, column: 1, offset: 0)
            )),
            createStatement(.assignment(
                target: .variable("undeclared2"),
                value: .literal(.integer(2)),
                position: SourcePosition(line: 2, column: 1, offset: 10)
            )),
            createStatement(.assignment(
                target: .variable("undeclared3"),
                value: .literal(.integer(3)),
                position: SourcePosition(line: 3, column: 1, offset: 20)
            ))
        ]
        
        let result = analyzer.analyze(statements: statements)
        
        #expect(!result.isSuccessful)
        #expect(result.errors.count == 3) // 2 undeclared errors + 1 too many errors
        
        let hasTooManyErrorsError = result.errors.contains { error in
            if case .tooManyErrors(count: _) = error {
                return true
            }
            return false
        }
        #expect(hasTooManyErrorsError)
    }
    
    // MARK: - Warning Tests
    
    @Test("Unused variable warning")
    func testUnusedVariableWarning() {
        let analyzer = createAnalyzer()
        
        let statements = [
            createStatement(.variableDeclaration(
                name: "unusedVar",
                dataType: .integer,
                initialValue: .literal(.integer(42)),
                position: SourcePosition(line: 1, column: 1, offset: 0)
            ))
        ]
        
        let result = analyzer.analyze(statements: statements)
        
        #expect(result.isSuccessful)
        #expect(result.hasWarnings)
        
        let hasUnusedVarWarning = result.warnings.contains { warning in
            if case .unusedVariable("unusedVar", at: _) = warning {
                return true
            }
            return false
        }
        #expect(hasUnusedVarWarning)
    }
}