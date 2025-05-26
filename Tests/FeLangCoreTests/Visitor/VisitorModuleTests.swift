import XCTest
@testable import FeLangCore

final class VisitorModuleTests: XCTestCase {
    
    // MARK: - Factory Method Tests
    
    func testDebugExpressionVisitorFactory() {
        let visitor = VisitorModule.debugExpressionVisitor()
        let expr = Expression.literal(.integer(42))
        let result = visitor.visit(expr)
        XCTAssertEqual(result, "Literal.integer(42)")
    }
    
    func testDebugStatementVisitorFactory() {
        let visitor = VisitorModule.debugStatementVisitor()
        let stmt = Statement.breakStatement
        let result = visitor.visit(stmt)
        XCTAssertEqual(result, "BreakStatement")
    }
    
    func testUnifiedDebugVisitorFactory() {
        let visitor = VisitorModule.unifiedDebugVisitor()
        
        let expr = Expression.literal(.integer(42))
        let exprResult = visitor.visitExpression(expr)
        XCTAssertEqual(exprResult, "Literal.integer(42)")
        
        let stmt = Statement.breakStatement
        let stmtResult = visitor.visitStatement(stmt)
        XCTAssertEqual(stmtResult, "BreakStatement")
    }
    
    // MARK: - Counter Visitor Tests
    
    func testExpressionCounterFactory() {
        let expr = Expression.binary(.add,
            Expression.literal(.integer(1)),
            Expression.literal(.integer(2))
        )
        
        let literalCounter = VisitorModule.expressionCounter { expr in
            if case .literal = expr {
                return true
            }
            return false
        }
        
        let count = literalCounter.visit(expr)
        XCTAssertEqual(count, 2)
    }
    
    func testStatementCounterFactory() {
        let stmt = Statement.block([
            Statement.breakStatement,
            Statement.breakStatement,
            Statement.returnStatement(ReturnStatement())
        ])
        
        let breakCounter = VisitorModule.statementCounter { stmt in
            if case .breakStatement = stmt {
                return true
            }
            return false
        }
        
        let count = breakCounter.visit(stmt)
        XCTAssertEqual(count, 2)
    }
    
    func testLiteralCounterFactory() {
        let expr = Expression.binary(.add,
            Expression.literal(.integer(1)),
            Expression.binary(.multiply,
                Expression.literal(.real(2.5)),
                Expression.literal(.string("hello"))
            )
        )
        
        let literalCounter = VisitorModule.literalCounter()
        let count = literalCounter.visit(expr)
        XCTAssertEqual(count, 3)
    }
    
    func testFunctionCallCounterFactory() {
        let expr = Expression.binary(.add,
            Expression.functionCall("func1", []),
            Expression.functionCall("func2", [
                Expression.functionCall("func3", [])
            ])
        )
        
        let functionCallCounter = VisitorModule.functionCallCounter()
        let count = functionCallCounter.visit(expr)
        XCTAssertEqual(count, 3)
    }
    
    func testVariableDeclarationCounterFactory() {
        let stmt = Statement.block([
            Statement.variableDeclaration(VariableDeclaration(name: "x", type: .integer)),
            Statement.variableDeclaration(VariableDeclaration(name: "y", type: .real)),
            Statement.breakStatement
        ])
        
        let varDeclCounter = VisitorModule.variableDeclarationCounter()
        let count = varDeclCounter.visit(stmt)
        XCTAssertEqual(count, 2)
    }
    
    // MARK: - Collection Visitor Tests
    
    func testIdentifierCollectorFactory() {
        let expr = Expression.binary(.add,
            Expression.identifier("x"),
            Expression.arrayAccess(
                Expression.identifier("arr"),
                Expression.identifier("index")
            )
        )
        
        let identifierCollector = VisitorModule.identifierCollector()
        let identifiers = identifierCollector.visit(expr)
        
        XCTAssertEqual(identifiers.count, 3)
        XCTAssertTrue(identifiers.contains("x"))
        XCTAssertTrue(identifiers.contains("arr"))
        XCTAssertTrue(identifiers.contains("index"))
    }
    
    func testFunctionNameCollectorFactory() {
        let expr = Expression.binary(.add,
            Expression.functionCall("func1", [
                Expression.functionCall("func2", [])
            ]),
            Expression.literal(.integer(42))
        )
        
        let functionNameCollector = VisitorModule.functionNameCollector()
        let functionNames = functionNameCollector.visit(expr)
        
        XCTAssertEqual(functionNames.count, 2)
        XCTAssertTrue(functionNames.contains("func1"))
        XCTAssertTrue(functionNames.contains("func2"))
    }
    
    // MARK: - Validation Visitor Tests
    
    func testExpressionValidatorFactory() {
        let validExpr = Expression.binary(.add,
            Expression.identifier("x"),
            Expression.literal(.integer(5))
        )
        
        let validator = VisitorModule.expressionValidator()
        let validIssues = validator.visit(validExpr)
        XCTAssertEqual(validIssues.count, 0)
        
        // Test division by zero detection
        let divByZeroExpr = Expression.binary(.divide,
            Expression.literal(.integer(10)),
            Expression.literal(.integer(0))
        )
        
        let divByZeroIssues = validator.visit(divByZeroExpr)
        XCTAssertEqual(divByZeroIssues.count, 1)
        XCTAssertTrue(divByZeroIssues[0].contains("Division by zero"))
        
        // Test empty identifier detection
        let emptyIdExpr = Expression.identifier("")
        let emptyIdIssues = validator.visit(emptyIdExpr)
        XCTAssertEqual(emptyIdIssues.count, 1)
        XCTAssertTrue(emptyIdIssues[0].contains("Empty identifier"))
        
        // Test empty field name detection
        let emptyFieldExpr = Expression.fieldAccess(Expression.identifier("obj"), "")
        let emptyFieldIssues = validator.visit(emptyFieldExpr)
        XCTAssertEqual(emptyFieldIssues.count, 1)
        XCTAssertTrue(emptyFieldIssues[0].contains("Empty field name"))
        
        // Test empty function name detection
        let emptyFuncExpr = Expression.functionCall("", [])
        let emptyFuncIssues = validator.visit(emptyFuncExpr)
        XCTAssertEqual(emptyFuncIssues.count, 1)
        XCTAssertTrue(emptyFuncIssues[0].contains("Empty function name"))
    }
    
    func testDivisionByZeroRealDetection() {
        let divByZeroRealExpr = Expression.binary(.divide,
            Expression.literal(.real(10.0)),
            Expression.literal(.real(0.0))
        )
        
        let validator = VisitorModule.expressionValidator()
        let issues = validator.visit(divByZeroRealExpr)
        XCTAssertEqual(issues.count, 1)
        XCTAssertTrue(issues[0].contains("Division by zero"))
    }
    
    // MARK: - Transformation Utility Tests
    
    func testIdentityExpressionTransformerFactory() {
        let expr = Expression.binary(.add,
            Expression.literal(.integer(1)),
            Expression.literal(.integer(2))
        )
        
        let identityTransformer = VisitorModule.identityExpressionTransformer()
        let result = identityTransformer.transform(expr)
        
        // Should be identical
        XCTAssertEqual(ExpressionVisitor.debug.visit(expr), ExpressionVisitor.debug.visit(result))
    }
    
    func testIdentityStatementTransformerFactory() {
        let stmt = Statement.block([Statement.breakStatement])
        
        let identityTransformer = VisitorModule.identityStatementTransformer()
        let result = identityTransformer.transform(stmt)
        
        // Should be identical
        XCTAssertEqual(StatementVisitor.debug.visit(stmt), StatementVisitor.debug.visit(result))
    }
    
    func testIdentifierReplacerFactory() {
        let expr = Expression.binary(.add,
            Expression.identifier("oldName"),
            Expression.identifier("otherVar")
        )
        
        let replacer = VisitorModule.identifierReplacer(from: "oldName", to: "newName")
        let result = replacer.transform(expr)
        
        let resultStr = ExpressionVisitor.debug.visit(result)
        XCTAssertTrue(resultStr.contains("newName"))
        XCTAssertFalse(resultStr.contains("oldName"))
        XCTAssertTrue(resultStr.contains("otherVar")) // Other identifiers unchanged
    }
    
    // MARK: - Walking Utility Tests
    
    func testWalkExpressionUtility() {
        let expr = Expression.binary(.add,
            Expression.literal(.integer(1)),
            Expression.literal(.integer(2))
        )
        
        let results = VisitorModule.walkExpression(expr)
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results[0].contains("Binary"))
        XCTAssertTrue(results[1].contains("Literal.integer(1)"))
        XCTAssertTrue(results[2].contains("Literal.integer(2)"))
    }
    
    func testWalkStatementUtility() {
        let stmt = Statement.block([Statement.breakStatement])
        
        let results = VisitorModule.walkStatement(stmt)
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results[0].contains("Block"))
        XCTAssertEqual(results[1], "BreakStatement")
    }
    
    func testCollectExpressionsUtility() {
        let expr = Expression.binary(.add,
            Expression.literal(.integer(1)),
            Expression.literal(.integer(2))
        )
        
        // Collect all expressions (default predicate)
        let allExpressions = VisitorModule.collectExpressions(from: expr)
        XCTAssertEqual(allExpressions.count, 3)
        
        // Collect only literals
        let literals = VisitorModule.collectExpressions(from: expr) { expr in
            if case .literal = expr {
                return true
            }
            return false
        }
        XCTAssertEqual(literals.count, 2)
    }
    
    func testCollectStatementsUtility() {
        let stmt = Statement.block([
            Statement.breakStatement,
            Statement.returnStatement(ReturnStatement())
        ])
        
        // Collect all statements (default predicate)
        let allStatements = VisitorModule.collectStatements(from: stmt)
        XCTAssertEqual(allStatements.count, 3) // block + break + return
        
        // Collect only break statements
        let breakStatements = VisitorModule.collectStatements(from: stmt) { stmt in
            if case .breakStatement = stmt {
                return true
            }
            return false
        }
        XCTAssertEqual(breakStatements.count, 1)
    }
    
    // MARK: - Convenience Extension Tests
    
    func testExpressionVisitConvenience() {
        let expr = Expression.literal(.integer(42))
        let visitor = ExpressionVisitor.debug
        
        let result = expr.visit(visitor)
        XCTAssertEqual(result, "Literal.integer(42)")
    }
    
    func testExpressionDebugDescriptionConvenience() {
        let expr = Expression.binary(.add,
            Expression.literal(.integer(1)),
            Expression.literal(.integer(2))
        )
        
        let debugDescription = expr.debugDescription
        XCTAssertTrue(debugDescription.contains("Binary"))
        XCTAssertTrue(debugDescription.contains("Literal.integer(1)"))
        XCTAssertTrue(debugDescription.contains("Literal.integer(2)"))
    }
    
    func testExpressionValidationIssuesConvenience() {
        let expr = Expression.binary(.divide,
            Expression.literal(.integer(10)),
            Expression.literal(.integer(0))
        )
        
        let issues = expr.validationIssues
        XCTAssertEqual(issues.count, 1)
        XCTAssertTrue(issues[0].contains("Division by zero"))
    }
    
    func testExpressionIdentifiersConvenience() {
        let expr = Expression.binary(.add,
            Expression.identifier("x"),
            Expression.identifier("y")
        )
        
        let identifiers = expr.identifiers
        XCTAssertEqual(identifiers.count, 2)
        XCTAssertTrue(identifiers.contains("x"))
        XCTAssertTrue(identifiers.contains("y"))
    }
    
    func testExpressionFunctionNamesConvenience() {
        let expr = Expression.functionCall("func1", [
            Expression.functionCall("func2", [])
        ])
        
        let functionNames = expr.functionNames
        XCTAssertEqual(functionNames.count, 2)
        XCTAssertTrue(functionNames.contains("func1"))
        XCTAssertTrue(functionNames.contains("func2"))
    }
    
    func testStatementVisitConvenience() {
        let stmt = Statement.breakStatement
        let visitor = StatementVisitor.debug
        
        let result = stmt.visit(visitor)
        XCTAssertEqual(result, "BreakStatement")
    }
    
    func testStatementDebugDescriptionConvenience() {
        let stmt = Statement.returnStatement(ReturnStatement(expression: Expression.literal(.integer(42))))
        
        let debugDescription = stmt.debugDescription
        XCTAssertTrue(debugDescription.contains("ReturnStatement"))
        XCTAssertTrue(debugDescription.contains("Literal.integer(42)"))
    }
    
    // MARK: - Complex Integration Tests
    
    func testComplexExpressionAnalysis() {
        // Create a complex expression with multiple issues
        let complexExpr = Expression.functionCall("", [ // Empty function name
            Expression.binary(.divide,
                Expression.identifier("x"),
                Expression.literal(.integer(0)) // Division by zero
            ),
            Expression.fieldAccess(
                Expression.identifier(""), // Empty identifier
                "" // Empty field name
            )
        ])
        
        let issues = complexExpr.validationIssues
        XCTAssertEqual(issues.count, 4)
        XCTAssertTrue(issues.contains { $0.contains("Empty function name") })
        XCTAssertTrue(issues.contains { $0.contains("Division by zero") })
        XCTAssertTrue(issues.contains { $0.contains("Empty identifier") })
        XCTAssertTrue(issues.contains { $0.contains("Empty field name") })
    }
    
    func testMixedVisitorUsage() {
        let expr = Expression.binary(.add,
            Expression.functionCall("func", [Expression.identifier("x")]),
            Expression.literal(.integer(42))
        )
        
        // Use multiple visitors on the same expression
        let literalCount = VisitorModule.literalCounter().visit(expr)
        let functionCount = VisitorModule.functionCallCounter().visit(expr)
        let identifiers = expr.identifiers
        let functionNames = expr.functionNames
        let issues = expr.validationIssues
        
        XCTAssertEqual(literalCount, 1)
        XCTAssertEqual(functionCount, 1)
        XCTAssertEqual(identifiers, ["x"])
        XCTAssertEqual(functionNames, ["func"])
        XCTAssertEqual(issues.count, 0) // No validation issues
    }
    
    // MARK: - Performance Tests
    
    func testVisitorModulePerformance() {
        // Create a moderately complex expression
        var expr = Expression.literal(.integer(0))
        for i in 1...50 {
            expr = Expression.binary(.add, expr, Expression.functionCall("func\(i)", [Expression.identifier("var\(i)")]))
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Perform multiple visitor operations
        _ = expr.identifiers
        _ = expr.functionNames
        _ = expr.validationIssues
        _ = VisitorModule.literalCounter().visit(expr)
        _ = VisitorModule.functionCallCounter().visit(expr)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Should complete quickly even with multiple operations
        XCTAssertLessThan(endTime - startTime, 1.0)
    }
    
    // MARK: - Edge Cases
    
    func testEmptyCollections() {
        let expr = Expression.literal(.integer(42))
        
        // Test collections that should be empty
        let functionNames = expr.functionNames
        XCTAssertEqual(functionNames.count, 0)
        
        let identifiers = expr.identifiers
        XCTAssertEqual(identifiers.count, 0)
    }
    
    func testVisitorWithNilValues() {
        let stmt = Statement.returnStatement(ReturnStatement(expression: nil))
        
        let debugDescription = stmt.debugDescription
        XCTAssertTrue(debugDescription.contains("ReturnStatement(nil)"))
    }
}