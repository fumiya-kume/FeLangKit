@testable import FeLangRuntime
import FeLangCore
import Foundation
import Testing

final class EvaluationTracker: @unchecked Sendable {
    private(set) var wasEvaluated = false

    func markEvaluated() {
        wasEvaluated = true
    }
}

// MARK: - RuntimeValue Tests

struct RuntimeValueTests {

    // MARK: - Basic Value Tests

    @Test func testIntegerValue() {
        let value = RuntimeValue.integer(42)
        #expect(value.typeName == "Integer")
        #expect(value.toString() == "42")
    }

    @Test func testRealValue() {
        let value = RuntimeValue.real(3.14)
        #expect(value.typeName == "Real")
        #expect(value.toString() == "3.14")
    }

    @Test func testStringValue() {
        let value = RuntimeValue.string("hello")
        #expect(value.typeName == "String")
        #expect(value.toString() == "hello")
    }

    @Test func testCharacterValue() {
        let value = RuntimeValue.character("A")
        #expect(value.typeName == "Character")
        #expect(value.toString() == "A")
    }

    @Test func testBooleanValue() {
        let trueValue = RuntimeValue.boolean(true)
        let falseValue = RuntimeValue.boolean(false)

        #expect(trueValue.typeName == "Boolean")
        #expect(trueValue.toString() == "true")
        #expect(falseValue.toString() == "false")
    }

    @Test func testArrayValue() {
        let value = RuntimeValue.array([.integer(1), .integer(2), .integer(3)])
        #expect(value.typeName == "Array")
        #expect(value.toString() == "[1, 2, 3]")
    }

    @Test func testNullValue() {
        let value = RuntimeValue.null
        #expect(value.typeName == "Null")
        #expect(value.toString() == "null")
    }

    @Test func testUndefinedValue() {
        let value = RuntimeValue.undefined
        #expect(value.typeName == "Undefined")
        #expect(value.toString() == "未定義")
    }

    @Test func testIsTruthyUndefined() {
        #expect(RuntimeValue.undefined.isTruthy == false)
    }

    // MARK: - Truthy Tests

    @Test func testIsTruthyBoolean() {
        #expect(RuntimeValue.boolean(true).isTruthy == true)
        #expect(RuntimeValue.boolean(false).isTruthy == false)
    }

    @Test func testIsTruthyInteger() {
        #expect(RuntimeValue.integer(1).isTruthy == true)
        #expect(RuntimeValue.integer(0).isTruthy == false)
        #expect(RuntimeValue.integer(-1).isTruthy == true)
    }

    @Test func testIsTruthyNull() {
        #expect(RuntimeValue.null.isTruthy == false)
    }

    @Test func testIsTruthyOtherTypes() {
        #expect(RuntimeValue.string("").isTruthy == true)
        #expect(RuntimeValue.string("hello").isTruthy == true)
        #expect(RuntimeValue.real(0.0).isTruthy == true)
        #expect(RuntimeValue.array([]).isTruthy == true)
    }

    // MARK: - Conversion Tests

    @Test func testToInteger() {
        #expect(RuntimeValue.integer(42).toInteger() == 42)
        #expect(RuntimeValue.real(3.14).toInteger() == 3)
        #expect(RuntimeValue.string("123").toInteger() == 123)
        #expect(RuntimeValue.boolean(true).toInteger() == 1)
        #expect(RuntimeValue.boolean(false).toInteger() == 0)
        #expect(RuntimeValue.null.toInteger() == nil)
    }

    @Test func testToReal() {
        #expect(RuntimeValue.integer(42).toReal() == 42.0)
        #expect(RuntimeValue.real(3.14).toReal() == 3.14)
        #expect(RuntimeValue.string("3.14").toReal() == 3.14)
        #expect(RuntimeValue.null.toReal() == nil)
    }

    @Test func testToString() {
        #expect(RuntimeValue.integer(42).toString() == "42")
        #expect(RuntimeValue.real(3.14).toString() == "3.14")
        #expect(RuntimeValue.string("hello").toString() == "hello")
        #expect(RuntimeValue.boolean(true).toString() == "true")
        #expect(RuntimeValue.null.toString() == "null")
    }

    // MARK: - Equality Tests

    @Test func testValueEquality() {
        #expect(RuntimeValue.integer(42) == RuntimeValue.integer(42))
        #expect(RuntimeValue.integer(42) != RuntimeValue.integer(43))
        #expect(RuntimeValue.string("hello") == RuntimeValue.string("hello"))
        #expect(RuntimeValue.boolean(true) == RuntimeValue.boolean(true))
        #expect(RuntimeValue.null == RuntimeValue.null)
    }

    @Test func testRecordValue() {
        let record = RuntimeValue.record(["name": .string("Alice"), "age": .integer(30)])
        #expect(record.typeName == "Record")
        #expect(record.toString().contains("name"))
        #expect(record.toString().contains("Alice"))
    }
}

// MARK: - Environment Tests

struct EnvironmentTests {

    @Test func testDefineAndLookup() {
        let env = Environment()
        env.define("x", value: .integer(42))

        #expect(env.lookup("x") == .integer(42))
        #expect(env.exists("x") == true)
        #expect(env.lookup("y") == nil)
        #expect(env.exists("y") == false)
    }

    @Test func testNestedScopes() throws {
        let env = Environment()
        env.define("x", value: .integer(1))

        try env.pushScope()
        env.define("y", value: .integer(2))

        #expect(env.lookup("x") == .integer(1))
        #expect(env.lookup("y") == .integer(2))

        env.popScope()

        #expect(env.lookup("x") == .integer(1))
        #expect(env.lookup("y") == nil)
    }

    @Test func testShadowing() throws {
        let env = Environment()
        env.define("x", value: .integer(1))

        try env.pushScope()
        env.define("x", value: .integer(2))
        #expect(env.lookup("x") == .integer(2))

        env.popScope()
        #expect(env.lookup("x") == .integer(1))
    }

    @Test func testConstantDefinition() throws {
        let env = Environment()
        env.define("PI", value: .real(3.14159), isConstant: true)

        #expect(env.lookup("PI") == .real(3.14159))
        #expect(env.isConstant("PI") == true)
    }

    @Test func testConstantReassignmentError() throws {
        let env = Environment()
        env.define("PI", value: .real(3.14159), isConstant: true)

        #expect(throws: RuntimeError.self) {
            try env.assign("PI", value: .real(3.0))
        }
    }

    @Test func testVariableAssignment() throws {
        let env = Environment()
        env.define("x", value: .integer(1))

        try env.assign("x", value: .integer(2))
        #expect(env.lookup("x") == .integer(2))
    }

    @Test func testUndefinedVariableAssignment() throws {
        let env = Environment()

        #expect(throws: RuntimeError.self) {
            try env.assign("x", value: .integer(1))
        }
    }

    @Test func testScopeDepthLimit() throws {
        let env = Environment(maxScopeDepth: 5)

        for _ in 0..<4 {
            try env.pushScope()
        }

        #expect(throws: RuntimeError.self) {
            try env.pushScope()
        }
    }

    @Test func testCallDepthLimit() throws {
        let env = Environment(maxCallDepth: 3)

        try env.enterCall()
        try env.enterCall()

        #expect(throws: RuntimeError.self) {
            try env.enterCall()
        }
    }

    @Test func testImportVariables() {
        let env = Environment()
        env.importVariables(["a": .integer(1), "b": .integer(2)])

        #expect(env.lookup("a") == .integer(1))
        #expect(env.lookup("b") == .integer(2))
    }

    @Test func testCaptureEnvironment() throws {
        let env = Environment()
        env.define("x", value: .integer(1))

        try env.pushScope()
        env.define("y", value: .integer(2))

        let captured = env.captureEnvironment()
        #expect(captured["x"] == .integer(1))
        #expect(captured["y"] == .integer(2))
    }

    @Test func testVisibleVariables() throws {
        let env = Environment()
        env.define("a", value: .integer(1))
        env.define("b", value: .integer(2))

        let visible = env.visibleVariables
        #expect(visible.contains("a"))
        #expect(visible.contains("b"))
    }
}

// MARK: - ExpressionEvaluator Tests

struct ExpressionEvaluatorTests {

    private func makeEvaluator() -> ExpressionEvaluator {
        let env = Environment()
        env.define("x", value: .integer(10))
        env.define("y", value: .real(3.5))
        env.define("name", value: .string("Alice"))
        env.define("arr", value: .array([.integer(1), .integer(2), .integer(3)]))

        return ExpressionEvaluator(environment: env) { _, _ in
            throw RuntimeError.undefinedFunction(name: "unknown")
        }
    }

    @Test func testEvaluateIntegerLiteral() throws {
        let evaluator = makeEvaluator()
        let result = try evaluator.evaluate(.literal(.integer(42)))
        #expect(result == .integer(42))
    }

    @Test func testEvaluateRealLiteral() throws {
        let evaluator = makeEvaluator()
        let result = try evaluator.evaluate(.literal(.real(3.14)))
        #expect(result == .real(3.14))
    }

    @Test func testEvaluateStringLiteral() throws {
        let evaluator = makeEvaluator()
        let result = try evaluator.evaluate(.literal(.string("hello")))
        #expect(result == .string("hello"))
    }

    @Test func testEvaluateBooleanLiteral() throws {
        let evaluator = makeEvaluator()
        let trueResult = try evaluator.evaluate(.literal(.boolean(true)))
        let falseResult = try evaluator.evaluate(.literal(.boolean(false)))
        #expect(trueResult == .boolean(true))
        #expect(falseResult == .boolean(false))
    }

    @Test func testEvaluateUndefinedLiteral() throws {
        let evaluator = makeEvaluator()
        let result = try evaluator.evaluate(.literal(.undefined))
        #expect(result == .undefined)
    }

    @Test func testEvaluateIdentifier() throws {
        let evaluator = makeEvaluator()
        let result = try evaluator.evaluate(.identifier("x"))
        #expect(result == .integer(10))
    }

    @Test func testEvaluateUndefinedIdentifier() throws {
        let evaluator = makeEvaluator()
        #expect(throws: RuntimeError.self) {
            _ = try evaluator.evaluate(.identifier("undefined"))
        }
    }

    // MARK: - Binary Operations

    @Test func testAddIntegers() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.add, .literal(.integer(2)), .literal(.integer(3)))
        let result = try evaluator.evaluate(expr)
        #expect(result == .integer(5))
    }

    @Test func testAddReals() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.add, .literal(.real(1.5)), .literal(.real(2.5)))
        let result = try evaluator.evaluate(expr)
        #expect(result == .real(4.0))
    }

    @Test func testAddMixedNumeric() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.add, .literal(.integer(1)), .literal(.real(2.5)))
        let result = try evaluator.evaluate(expr)
        #expect(result == .real(3.5))
    }

    @Test func testAddStrings() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.add, .literal(.string("Hello, ")), .literal(.string("World!")))
        let result = try evaluator.evaluate(expr)
        #expect(result == .string("Hello, World!"))
    }

    @Test func testSubtract() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.subtract, .literal(.integer(10)), .literal(.integer(3)))
        let result = try evaluator.evaluate(expr)
        #expect(result == .integer(7))
    }

    @Test func testMultiply() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.multiply, .literal(.integer(4)), .literal(.integer(5)))
        let result = try evaluator.evaluate(expr)
        #expect(result == .integer(20))
    }

    @Test func testDivide() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.divide, .literal(.integer(10)), .literal(.integer(3)))
        let result = try evaluator.evaluate(expr)
        #expect(result == .integer(3))
    }

    @Test func testDivideWithUnicodeOperator() throws {
        let evaluator = makeEvaluator()
        let tokens = try ParsingTokenizer.tokenize("10 ÷ 3")
        let parser = ExpressionParser()
        let expr = try parser.parseExpression(from: tokens)
        let result = try evaluator.evaluate(expr)
        #expect(result == .integer(3))
    }

    @Test func testDivideByZeroError() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.divide, .literal(.integer(10)), .literal(.integer(0)))
        #expect(throws: RuntimeError.self) {
            _ = try evaluator.evaluate(expr)
        }
    }

    @Test func testModulo() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.modulo, .literal(.integer(10)), .literal(.integer(3)))
        let result = try evaluator.evaluate(expr)
        #expect(result == .integer(1))
    }

    @Test func testModuloNegativeDividend() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.modulo, .literal(.integer(-17)), .literal(.integer(5)))
        let result = try evaluator.evaluate(expr)
        #expect(result == .integer(-2))
    }

    // MARK: - Comparison Operations

    @Test func testEqual() throws {
        let evaluator = makeEvaluator()
        let equalExpr = Expression.binary(.equal, .literal(.integer(5)), .literal(.integer(5)))
        let notEqualExpr = Expression.binary(.equal, .literal(.integer(5)), .literal(.integer(6)))

        #expect(try evaluator.evaluate(equalExpr) == .boolean(true))
        #expect(try evaluator.evaluate(notEqualExpr) == .boolean(false))
    }

    @Test func testNotEqual() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.notEqual, .literal(.integer(5)), .literal(.integer(6)))
        #expect(try evaluator.evaluate(expr) == .boolean(true))
    }

    @Test func testLess() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.less, .literal(.integer(3)), .literal(.integer(5)))
        #expect(try evaluator.evaluate(expr) == .boolean(true))
    }

    @Test func testLessEqual() throws {
        let evaluator = makeEvaluator()
        let expr1 = Expression.binary(.lessEqual, .literal(.integer(3)), .literal(.integer(3)))
        let expr2 = Expression.binary(.lessEqual, .literal(.integer(3)), .literal(.integer(5)))

        #expect(try evaluator.evaluate(expr1) == .boolean(true))
        #expect(try evaluator.evaluate(expr2) == .boolean(true))
    }

    @Test func testGreater() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.greater, .literal(.integer(5)), .literal(.integer(3)))
        #expect(try evaluator.evaluate(expr) == .boolean(true))
    }

    @Test func testGreaterEqual() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.greaterEqual, .literal(.integer(5)), .literal(.integer(5)))
        #expect(try evaluator.evaluate(expr) == .boolean(true))
    }

    // MARK: - Logical Operations

    @Test func testLogicalAnd() throws {
        let evaluator = makeEvaluator()
        let trueAndTrue = Expression.binary(.and, .literal(.boolean(true)), .literal(.boolean(true)))
        let trueAndFalse = Expression.binary(.and, .literal(.boolean(true)), .literal(.boolean(false)))

        #expect(try evaluator.evaluate(trueAndTrue) == .boolean(true))
        #expect(try evaluator.evaluate(trueAndFalse) == .boolean(false))
    }

    @Test func testLogicalOr() throws {
        let evaluator = makeEvaluator()
        let falseOrTrue = Expression.binary(.or, .literal(.boolean(false)), .literal(.boolean(true)))
        let falseOrFalse = Expression.binary(.or, .literal(.boolean(false)), .literal(.boolean(false)))

        #expect(try evaluator.evaluate(falseOrTrue) == .boolean(true))
        #expect(try evaluator.evaluate(falseOrFalse) == .boolean(false))
    }

    // MARK: - Short-Circuit Evaluation Tests

    @Test func testAndShortCircuitSkipsRightWhenLeftIsFalse() throws {
        let tracker = EvaluationTracker()
        let env = Environment()
        let evaluator = ExpressionEvaluator(environment: env) { name, _ in
            if name == "sideEffect" {
                tracker.markEvaluated()
                return .boolean(true)
            }
            throw RuntimeError.undefinedFunction(name: name)
        }

        let expr = Expression.binary(
            .and,
            .literal(.boolean(false)),
            .functionCall("sideEffect", [])
        )
        let result = try evaluator.evaluate(expr)

        #expect(result == .boolean(false))
        #expect(tracker.wasEvaluated == false)
    }

    @Test func testAndEvaluatesRightWhenLeftIsTrue() throws {
        let tracker = EvaluationTracker()
        let env = Environment()
        let evaluator = ExpressionEvaluator(environment: env) { name, _ in
            if name == "sideEffect" {
                tracker.markEvaluated()
                return .boolean(true)
            }
            throw RuntimeError.undefinedFunction(name: name)
        }

        let expr = Expression.binary(
            .and,
            .literal(.boolean(true)),
            .functionCall("sideEffect", [])
        )
        let result = try evaluator.evaluate(expr)

        #expect(result == .boolean(true))
        #expect(tracker.wasEvaluated == true)
    }

    @Test func testOrShortCircuitSkipsRightWhenLeftIsTrue() throws {
        let tracker = EvaluationTracker()
        let env = Environment()
        let evaluator = ExpressionEvaluator(environment: env) { name, _ in
            if name == "sideEffect" {
                tracker.markEvaluated()
                return .boolean(false)
            }
            throw RuntimeError.undefinedFunction(name: name)
        }

        let expr = Expression.binary(
            .or,
            .literal(.boolean(true)),
            .functionCall("sideEffect", [])
        )
        let result = try evaluator.evaluate(expr)

        #expect(result == .boolean(true))
        #expect(tracker.wasEvaluated == false)
    }

    @Test func testOrEvaluatesRightWhenLeftIsFalse() throws {
        let tracker = EvaluationTracker()
        let env = Environment()
        let evaluator = ExpressionEvaluator(environment: env) { name, _ in
            if name == "sideEffect" {
                tracker.markEvaluated()
                return .boolean(true)
            }
            throw RuntimeError.undefinedFunction(name: name)
        }

        let expr = Expression.binary(
            .or,
            .literal(.boolean(false)),
            .functionCall("sideEffect", [])
        )
        let result = try evaluator.evaluate(expr)

        #expect(result == .boolean(true))
        #expect(tracker.wasEvaluated == true)
    }

    @Test func testAndShortCircuitAvoidsErrorInRight() throws {
        let env = Environment()
        let evaluator = ExpressionEvaluator(environment: env) { name, _ in
            throw RuntimeError.undefinedFunction(name: name)
        }

        let expr = Expression.binary(
            .and,
            .literal(.boolean(false)),
            .functionCall("throwingFunction", [])
        )
        let result = try evaluator.evaluate(expr)
        #expect(result == .boolean(false))
    }

    @Test func testOrShortCircuitAvoidsErrorInRight() throws {
        let env = Environment()
        let evaluator = ExpressionEvaluator(environment: env) { name, _ in
            throw RuntimeError.undefinedFunction(name: name)
        }

        let expr = Expression.binary(
            .or,
            .literal(.boolean(true)),
            .functionCall("throwingFunction", [])
        )
        let result = try evaluator.evaluate(expr)
        #expect(result == .boolean(true))
    }

    // MARK: - Bitwise Operations

    @Test func testBitwiseAnd() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.bitwiseAnd, .literal(.integer(5)), .literal(.integer(3)))
        let result = try evaluator.evaluate(expr)
        #expect(result == .integer(1))
    }

    @Test func testBitwiseAndWithZero() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.bitwiseAnd, .literal(.integer(255)), .literal(.integer(0)))
        let result = try evaluator.evaluate(expr)
        #expect(result == .integer(0))
    }

    @Test func testBitwiseAndWithAllOnes() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.bitwiseAnd, .literal(.integer(15)), .literal(.integer(15)))
        let result = try evaluator.evaluate(expr)
        #expect(result == .integer(15))
    }

    @Test func testBitwiseAndTypeMismatchLeft() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.bitwiseAnd, .literal(.real(5.0)), .literal(.integer(3)))
        #expect(throws: RuntimeError.self) {
            _ = try evaluator.evaluate(expr)
        }
    }

    @Test func testBitwiseAndTypeMismatchRight() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.bitwiseAnd, .literal(.integer(5)), .literal(.real(3.0)))
        #expect(throws: RuntimeError.self) {
            _ = try evaluator.evaluate(expr)
        }
    }

    @Test func testBitwiseOr() throws {
        let evaluator = makeEvaluator()
        // 5 = 0b101, 3 = 0b011, 5 | 3 = 0b111 = 7
        let expr = Expression.binary(.bitwiseOr, .literal(.integer(5)), .literal(.integer(3)))
        let result = try evaluator.evaluate(expr)
        #expect(result == .integer(7))
    }

    @Test func testBitwiseOrWithZero() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.bitwiseOr, .literal(.integer(255)), .literal(.integer(0)))
        let result = try evaluator.evaluate(expr)
        #expect(result == .integer(255))
    }

    @Test func testBitwiseOrWithAllOnes() throws {
        let evaluator = makeEvaluator()
        // 15 = 0b1111, 15 | 15 = 0b1111 = 15
        let expr = Expression.binary(.bitwiseOr, .literal(.integer(15)), .literal(.integer(15)))
        let result = try evaluator.evaluate(expr)
        #expect(result == .integer(15))
    }

    @Test func testBitwiseOrTypeMismatchLeft() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.bitwiseOr, .literal(.real(5.0)), .literal(.integer(3)))
        #expect(throws: RuntimeError.self) {
            _ = try evaluator.evaluate(expr)
        }
    }

    @Test func testBitwiseOrTypeMismatchRight() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.bitwiseOr, .literal(.integer(5)), .literal(.real(3.0)))
        #expect(throws: RuntimeError.self) {
            _ = try evaluator.evaluate(expr)
        }
    }

    @Test func testLeftShift() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.leftShift, .literal(.integer(1)), .literal(.integer(3)))
        let result = try evaluator.evaluate(expr)
        #expect(result == .integer(8))
    }

    @Test func testRightShift() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.rightShift, .literal(.integer(16)), .literal(.integer(2)))
        let result = try evaluator.evaluate(expr)
        #expect(result == .integer(4))
    }

    @Test func testLeftShiftTypeMismatchLeft() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.leftShift, .literal(.real(1.0)), .literal(.integer(3)))
        #expect(throws: RuntimeError.self) {
            _ = try evaluator.evaluate(expr)
        }
    }

    @Test func testLeftShiftTypeMismatchRight() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.leftShift, .literal(.integer(1)), .literal(.real(3.0)))
        #expect(throws: RuntimeError.self) {
            _ = try evaluator.evaluate(expr)
        }
    }

    @Test func testRightShiftTypeMismatchLeft() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.rightShift, .literal(.real(16.0)), .literal(.integer(2)))
        #expect(throws: RuntimeError.self) {
            _ = try evaluator.evaluate(expr)
        }
    }

    @Test func testRightShiftTypeMismatchRight() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.binary(.rightShift, .literal(.integer(16)), .literal(.real(2.0)))
        #expect(throws: RuntimeError.self) {
            _ = try evaluator.evaluate(expr)
        }
    }

    // MARK: - Unary Operations

    @Test func testUnaryMinus() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.unary(.minus, .literal(.integer(42)))
        #expect(try evaluator.evaluate(expr) == .integer(-42))
    }

    @Test func testUnaryNot() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.unary(.not, .literal(.boolean(true)))
        #expect(try evaluator.evaluate(expr) == .boolean(false))
    }

    // MARK: - Array Access

    @Test func testArrayAccess() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.arrayAccess(.identifier("arr"), .literal(.integer(0)))
        #expect(try evaluator.evaluate(expr) == .integer(1))
    }

    @Test func testArrayAccessOutOfBounds() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.arrayAccess(.identifier("arr"), .literal(.integer(10)))
        #expect(throws: RuntimeError.self) {
            _ = try evaluator.evaluate(expr)
        }
    }

    @Test func testArrayLiteral() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.arrayLiteral([.literal(.integer(1)), .literal(.integer(2))])
        let result = try evaluator.evaluate(expr)
        #expect(result == .array([.integer(1), .integer(2)]))
    }

    @Test func testMethodCallThrowsNotSupportedError() throws {
        let evaluator = makeEvaluator()
        let expr = Expression.methodCall(.identifier("obj"), "getValue", [])
        #expect(throws: RuntimeError.self) {
            _ = try evaluator.evaluate(expr)
        }
    }
}

// MARK: - StatementExecutor Tests

struct StatementExecutorTests {

    @Test func testVariableDeclaration() throws {
        let env = Environment()
        let executor = StatementExecutor(environment: env)

        let decl = VariableDeclaration(
            name: "x",
            type: .integer,
            initialValue: .literal(.integer(42))
        )
        _ = try executor.executeStatement(.variableDeclaration(decl))

        #expect(env.lookup("x") == .integer(42))
    }

    @Test func testConstantDeclaration() throws {
        let env = Environment()
        let executor = StatementExecutor(environment: env)

        let decl = ConstantDeclaration(
            name: "PI",
            type: .real,
            initialValue: .literal(.real(3.14159))
        )
        _ = try executor.executeStatement(.constantDeclaration(decl))

        #expect(env.lookup("PI") == .real(3.14159))
        #expect(env.isConstant("PI") == true)
    }

    @Test func testIfStatementThen() throws {
        let env = Environment()
        let executor = StatementExecutor(environment: env)

        env.define("result", value: .integer(0))

        let assignment = Statement.assignment(.variable(
            "result",
            .literal(.integer(1))
        ))

        let ifStmt = IfStatement(
            condition: .literal(.boolean(true)),
            thenBody: [assignment],
            elseIfs: [],
            elseBody: nil
        )

        _ = try executor.executeStatement(.ifStatement(ifStmt))
        #expect(env.lookup("result") == .integer(1))
    }

    @Test func testIfStatementElse() throws {
        let env = Environment()
        let executor = StatementExecutor(environment: env)

        env.define("result", value: .integer(0))

        let thenAssign = Statement.assignment(.variable("result", .literal(.integer(1))))
        let elseAssign = Statement.assignment(.variable("result", .literal(.integer(2))))

        let ifStmt = IfStatement(
            condition: .literal(.boolean(false)),
            thenBody: [thenAssign],
            elseIfs: [],
            elseBody: [elseAssign]
        )

        _ = try executor.executeStatement(.ifStatement(ifStmt))
        #expect(env.lookup("result") == .integer(2))
    }

    @Test func testWhileLoop() throws {
        let env = Environment()
        let executor = StatementExecutor(environment: env)

        env.define("count", value: .integer(0))

        let increment = Statement.assignment(.variable(
            "count",
            .binary(.add, .identifier("count"), .literal(.integer(1)))
        ))

        let whileStmt = WhileStatement(
            condition: .binary(.less, .identifier("count"), .literal(.integer(5))),
            body: [increment]
        )

        _ = try executor.executeStatement(.whileStatement(whileStmt))
        #expect(env.lookup("count") == .integer(5))
    }

    @Test func testWhileLoopBreak() throws {
        let env = Environment()
        let executor = StatementExecutor(environment: env)

        env.define("count", value: .integer(0))

        let increment = Statement.assignment(.variable(
            "count",
            .binary(.add, .identifier("count"), .literal(.integer(1)))
        ))

        let ifBreak = Statement.ifStatement(IfStatement(
            condition: .binary(.equal, .identifier("count"), .literal(.integer(3))),
            thenBody: [.breakStatement],
            elseIfs: [],
            elseBody: nil
        ))

        let whileStmt = WhileStatement(
            condition: .literal(.boolean(true)),
            body: [increment, ifBreak]
        )

        _ = try executor.executeStatement(.whileStatement(whileStmt))
        #expect(env.lookup("count") == .integer(3))
    }

    @Test func testWhileLoopContinue() throws {
        let env = Environment()
        let executor = StatementExecutor(environment: env)

        env.define("count", value: .integer(0))
        env.define("sum", value: .integer(0))

        let incrementCount = Statement.assignment(.variable(
            "count",
            .binary(.add, .identifier("count"), .literal(.integer(1)))
        ))

        let ifContinue = Statement.ifStatement(IfStatement(
            condition: .binary(.equal,
                               .binary(.modulo, .identifier("count"), .literal(.integer(2))),
                               .literal(.integer(0))),
            thenBody: [.continueStatement],
            elseIfs: [],
            elseBody: nil
        ))

        let addToSum = Statement.assignment(.variable(
            "sum",
            .binary(.add, .identifier("sum"), .identifier("count"))
        ))

        let whileStmt = WhileStatement(
            condition: .binary(.less, .identifier("count"), .literal(.integer(5))),
            body: [incrementCount, ifContinue, addToSum]
        )

        _ = try executor.executeStatement(.whileStatement(whileStmt))
        // sum = 1 + 3 + 5 = 9 (skipping 2 and 4)
        #expect(env.lookup("sum") == .integer(9))
    }

    @Test func testDoWhileLoop() throws {
        let env = Environment()
        let executor = StatementExecutor(environment: env)

        env.define("count", value: .integer(0))

        let increment = Statement.assignment(.variable(
            "count",
            .binary(.add, .identifier("count"), .literal(.integer(1)))
        ))

        let doWhileStmt = DoWhileStatement(
            body: [increment],
            condition: .binary(.less, .identifier("count"), .literal(.integer(5)))
        )

        _ = try executor.executeStatement(.doWhileStatement(doWhileStmt))
        #expect(env.lookup("count") == .integer(5))
    }

    @Test func testDoWhileLoopExecutesAtLeastOnce() throws {
        let env = Environment()
        let executor = StatementExecutor(environment: env)

        env.define("count", value: .integer(0))

        let increment = Statement.assignment(.variable(
            "count",
            .binary(.add, .identifier("count"), .literal(.integer(1)))
        ))

        let doWhileStmt = DoWhileStatement(
            body: [increment],
            condition: .literal(.boolean(false))
        )

        _ = try executor.executeStatement(.doWhileStatement(doWhileStmt))
        #expect(env.lookup("count") == .integer(1))
    }

    @Test func testDoWhileLoopBreak() throws {
        let env = Environment()
        let executor = StatementExecutor(environment: env)

        env.define("count", value: .integer(0))

        let increment = Statement.assignment(.variable(
            "count",
            .binary(.add, .identifier("count"), .literal(.integer(1)))
        ))

        let ifBreak = Statement.ifStatement(IfStatement(
            condition: .binary(.equal, .identifier("count"), .literal(.integer(3))),
            thenBody: [.breakStatement],
            elseIfs: [],
            elseBody: nil
        ))

        let doWhileStmt = DoWhileStatement(
            body: [increment, ifBreak],
            condition: .literal(.boolean(true))
        )

        _ = try executor.executeStatement(.doWhileStatement(doWhileStmt))
        #expect(env.lookup("count") == .integer(3))
    }

    @Test func testDoWhileLoopContinue() throws {
        let env = Environment()
        let executor = StatementExecutor(environment: env)

        env.define("count", value: .integer(0))
        env.define("sum", value: .integer(0))

        let incrementCount = Statement.assignment(.variable(
            "count",
            .binary(.add, .identifier("count"), .literal(.integer(1)))
        ))

        let ifContinue = Statement.ifStatement(IfStatement(
            condition: .binary(.equal,
                               .binary(.modulo, .identifier("count"), .literal(.integer(2))),
                               .literal(.integer(0))),
            thenBody: [.continueStatement],
            elseIfs: [],
            elseBody: nil
        ))

        let addToSum = Statement.assignment(.variable(
            "sum",
            .binary(.add, .identifier("sum"), .identifier("count"))
        ))

        let doWhileStmt = DoWhileStatement(
            body: [incrementCount, ifContinue, addToSum],
            condition: .binary(.less, .identifier("count"), .literal(.integer(5)))
        )

        _ = try executor.executeStatement(.doWhileStatement(doWhileStmt))
        // sum = 1 + 3 + 5 = 9 (skipping 2 and 4)
        #expect(env.lookup("sum") == .integer(9))
    }

    @Test func testBreakOutsideLoopError() throws {
        let env = Environment()
        let executor = StatementExecutor(environment: env)

        #expect(throws: RuntimeError.self) {
            _ = try executor.executeStatement(.breakStatement)
        }
    }

    @Test func testContinueOutsideLoopError() throws {
        let env = Environment()
        let executor = StatementExecutor(environment: env)

        #expect(throws: RuntimeError.self) {
            _ = try executor.executeStatement(.continueStatement)
        }
    }

    @Test func testReturnStatement() throws {
        let env = Environment()
        let executor = StatementExecutor(environment: env)

        let returnStmt = ReturnStatement(expression: .literal(.integer(42)))
        #expect(throws: RuntimeError.self) {
            _ = try executor.executeStatement(.returnStatement(returnStmt))
        }
    }

    @Test func testBlockStatement() throws {
        let env = Environment()
        let executor = StatementExecutor(environment: env)

        let decl = VariableDeclaration(name: "x", type: .integer, initialValue: .literal(.integer(42)))
        let block = Statement.block([.variableDeclaration(decl)])

        _ = try executor.executeStatement(block)
        // Variable should not be visible outside block
        #expect(env.lookup("x") == nil)
    }

    // MARK: - Field Assignment Tests

    @Test func testRecordFieldAssignment() throws {
        let env = Environment()
        let executor = StatementExecutor(environment: env)

        // Define a record variable with initial fields
        env.define("p", value: .record(["x": .integer(0), "y": .integer(0)]))

        // Execute field assignment: p.x ← 10
        let fieldAccess = Assignment.FieldAccess(object: .identifier("p"), field: "x")
        let assignment = Statement.assignment(.fieldAccess(fieldAccess, .literal(.integer(10))))
        _ = try executor.executeStatement(assignment)

        // Verify the field was updated
        guard case .record(let fields) = env.lookup("p") else {
            #expect(Bool(false), "Expected record value")
            return
        }
        #expect(fields["x"] == .integer(10))
        #expect(fields["y"] == .integer(0))
    }

    @Test func testRecordFieldAssignmentWithExpression() throws {
        let env = Environment()
        let executor = StatementExecutor(environment: env)

        // Define variables
        env.define("p", value: .record(["x": .integer(5), "y": .integer(0)]))
        env.define("offset", value: .integer(3))

        // Execute field assignment: p.y ← p.x + offset
        let fieldAccess = Assignment.FieldAccess(object: .identifier("p"), field: "y")
        let valueExpr = Expression.binary(.add, .fieldAccess(.identifier("p"), "x"), .identifier("offset"))
        let assignment = Statement.assignment(.fieldAccess(fieldAccess, valueExpr))
        _ = try executor.executeStatement(assignment)

        // Verify the field was updated
        guard case .record(let fields) = env.lookup("p") else {
            #expect(Bool(false), "Expected record value")
            return
        }
        #expect(fields["y"] == .integer(8))
    }

    @Test func testInvalidFieldAssignment() throws {
        let env = Environment()
        let executor = StatementExecutor(environment: env)

        // Define a record without the target field
        env.define("p", value: .record(["x": .integer(0)]))

        // Try to assign to non-existent field: p.z ← 10
        let fieldAccess = Assignment.FieldAccess(object: .identifier("p"), field: "z")
        let assignment = Statement.assignment(.fieldAccess(fieldAccess, .literal(.integer(10))))

        #expect(throws: RuntimeError.self) {
            _ = try executor.executeStatement(assignment)
        }
    }

    @Test func testChainedFieldAssignmentNotSupported() throws {
        let env = Environment()
        let executor = StatementExecutor(environment: env)

        // Define nested records
        env.define("obj", value: .record(["inner": .record(["field": .integer(0)])]))

        // Try chained field assignment: obj.inner.field ← 10
        // The parser supports this syntax, but runtime only handles simple identifiers
        let chainedFieldAccess = Assignment.FieldAccess(
            object: .fieldAccess(.identifier("obj"), "inner"),
            field: "field"
        )
        let assignment = Statement.assignment(.fieldAccess(chainedFieldAccess, .literal(.integer(10))))

        #expect(throws: RuntimeError.self) {
            _ = try executor.executeStatement(assignment)
        }
    }
}

// MARK: - Interpreter Tests

struct InterpreterTests {

    @Test func testRunStatements() throws {
        let interpreter = Interpreter()

        let decl = VariableDeclaration(
            name: "x",
            type: .integer,
            initialValue: .literal(.integer(42))
        )

        try interpreter.run([.variableDeclaration(decl)])
        #expect(try interpreter.getVariable("x") == .integer(42))
    }

    @Test func testDefineAndGetVariable() throws {
        let interpreter = Interpreter()

        interpreter.defineVariable("greeting", value: .string("Hello"))
        #expect(try interpreter.getVariable("greeting") == .string("Hello"))
        #expect(interpreter.hasVariable("greeting") == true)
        #expect(interpreter.hasVariable("unknown") == false)
    }

    @Test func testRegisterAndCallFunction() throws {
        let interpreter = Interpreter()

        interpreter.registerFunction("double") { args in
            guard let first = args.first, case .integer(let value) = first else {
                throw RuntimeError.wrongArgumentCount(function: "double", expected: 1, actual: args.count)
            }
            return .integer(value * 2)
        }

        let result = try interpreter.callFunction("double", arguments: [.integer(21)])
        #expect(result == .integer(42))
    }

    @Test func testWithOutputCapture() throws {
        let (interpreter, getOutput) = Interpreter.withOutputCapture()

        // Use the standard library print function
        _ = try interpreter.callFunction("println", arguments: [.string("Hello, World!")])

        let output = getOutput()
        #expect(output == "Hello, World!\n")
    }

    @Test func testStandardLibraryIntegration() throws {
        let interpreter = Interpreter()

        // Test abs function
        let absResult = try interpreter.callFunction("abs", arguments: [.integer(-42)])
        #expect(absResult == .integer(42))

        // Test sqrt function
        let sqrtResult = try interpreter.callFunction("sqrt", arguments: [.integer(16)])
        #expect(sqrtResult == .real(4.0))

        // Test length function
        let lengthResult = try interpreter.callFunction("length", arguments: [.string("hello")])
        #expect(lengthResult == .integer(5))
    }
}

// MARK: - StandardLibrary Tests

struct StandardLibraryTests {

    // Helper class for thread-safe output capture
    private final class OutputCapture: @unchecked Sendable {
        private var _output = ""
        private let lock = NSLock()

        func append(_ text: String) {
            lock.lock()
            _output += text
            lock.unlock()
        }

        var output: String {
            lock.lock()
            defer { lock.unlock() }
            return _output
        }
    }

    @Test func testPrintFunction() throws {
        let capture = OutputCapture()
        let stdlib = StandardLibrary(
            printHandler: { capture.append($0) },
            inputHandler: { nil }
        )

        _ = try stdlib.functions["print"]?([.string("Hello")])
        #expect(capture.output == "Hello")
    }

    @Test func testPrintlnFunction() throws {
        let capture = OutputCapture()
        let stdlib = StandardLibrary(
            printHandler: { capture.append($0) },
            inputHandler: { nil }
        )

        _ = try stdlib.functions["println"]?([.string("Hello")])
        #expect(capture.output == "Hello\n")
    }

    @Test func testInputFunction() throws {
        let stdlib = StandardLibrary(
            printHandler: { _ in },
            inputHandler: { "test input" }
        )

        let result = try stdlib.functions["input"]?([])
        #expect(result == .string("test input"))
    }

    @Test func testToStringFunction() throws {
        let stdlib = StandardLibrary()

        let result = try stdlib.functions["toString"]?([.integer(42)])
        #expect(result == .string("42"))
    }

    @Test func testToIntegerFunction() throws {
        let stdlib = StandardLibrary()

        let result = try stdlib.functions["toInteger"]?([.string("42")])
        #expect(result == .integer(42))
    }

    @Test func testAbsFunction() throws {
        let stdlib = StandardLibrary()

        let intResult = try stdlib.functions["abs"]?([.integer(-42)])
        let realResult = try stdlib.functions["abs"]?([.real(-3.14)])

        #expect(intResult == .integer(42))
        #expect(realResult == .real(3.14))
    }

    @Test func testSqrtFunction() throws {
        let stdlib = StandardLibrary()

        let result = try stdlib.functions["sqrt"]?([.integer(16)])
        #expect(result == .real(4.0))
    }

    @Test func testPowFunction() throws {
        let stdlib = StandardLibrary()

        let result = try stdlib.functions["pow"]?([.integer(2), .integer(10)])
        #expect(result == .real(1024.0))
    }

    @Test func testMinMaxFunctions() throws {
        let stdlib = StandardLibrary()

        let minResult = try stdlib.functions["min"]?([.integer(5), .integer(3)])
        let maxResult = try stdlib.functions["max"]?([.integer(5), .integer(3)])

        #expect(minResult == .integer(3))
        #expect(maxResult == .integer(5))
    }

    @Test func testLengthFunction() throws {
        let stdlib = StandardLibrary()

        let strResult = try stdlib.functions["length"]?([.string("hello")])
        let arrResult = try stdlib.functions["length"]?([.array([.integer(1), .integer(2), .integer(3)])])

        #expect(strResult == .integer(5))
        #expect(arrResult == .integer(3))
    }

    @Test func testSubstringFunction() throws {
        let stdlib = StandardLibrary()

        let result = try stdlib.functions["substring"]?([.string("Hello, World!"), .integer(0), .integer(5)])
        #expect(result == .string("Hello"))
    }

    @Test func testCharAtFunction() throws {
        let stdlib = StandardLibrary()

        let result = try stdlib.functions["charAt"]?([.string("Hello"), .integer(0)])
        #expect(result == .character("H"))
    }

    @Test func testArrayAppendFunction() throws {
        let stdlib = StandardLibrary()

        let result = try stdlib.functions["append"]?([
            .array([.integer(1), .integer(2)]),
            .integer(3)
        ])
        #expect(result == .array([.integer(1), .integer(2), .integer(3)]))
    }

    @Test func testArrayPrependFunction() throws {
        let stdlib = StandardLibrary()

        let result = try stdlib.functions["prepend"]?([
            .array([.integer(2), .integer(3)]),
            .integer(1)
        ])
        #expect(result == .array([.integer(1), .integer(2), .integer(3)]))
    }
}

// MARK: - RuntimeError Tests

struct RuntimeErrorTests {

    @Test func testDivisionByZeroDescription() {
        let error = RuntimeError.divisionByZero
        #expect(error.description.contains("Division by zero"))
    }

    @Test func testIndexOutOfBoundsDescription() {
        let error = RuntimeError.indexOutOfBounds(index: 10, size: 5)
        #expect(error.description.contains("10"))
        #expect(error.description.contains("5"))
    }

    @Test func testTypeMismatchDescription() {
        let error = RuntimeError.typeMismatch(expected: "integer", actual: "string", operation: "+")
        #expect(error.description.contains("integer"))
        #expect(error.description.contains("string"))
    }

    @Test func testUndefinedVariableDescription() {
        let error = RuntimeError.undefinedVariable(name: "x")
        #expect(error.description.contains("x"))
    }

    @Test func testUndefinedFunctionDescription() {
        let error = RuntimeError.undefinedFunction(name: "foo")
        #expect(error.description.contains("foo"))
    }

    @Test func testWrongArgumentCountDescription() {
        let error = RuntimeError.wrongArgumentCount(function: "test", expected: 2, actual: 3)
        #expect(error.description.contains("test"))
        #expect(error.description.contains("2"))
        #expect(error.description.contains("3"))
    }

    @Test func testCannotAssignToConstantDescription() {
        let error = RuntimeError.cannotAssignToConstant(name: "PI")
        #expect(error.description.contains("PI"))
    }

    @Test func testStackOverflowDescription() {
        let error = RuntimeError.stackOverflow
        #expect(error.description.contains("Stack overflow"))
    }

    @Test func testMethodCallNotSupportedDescription() {
        let error = RuntimeError.methodCallNotSupported(method: "getValue")
        #expect(error.description.contains("getValue"))
        #expect(error.description.contains("not supported"))
    }
}

// MARK: - Class Inheritance Tests

struct ClassInheritanceTests {

    @Test func testSubclassInheritsSuperclassMemberVariables() throws {
        let env = Environment()
        let executor = StatementExecutor(environment: env)

        // Define superclass Animal with member 'name'
        let animalClass = ClassDeclaration(
            name: "Animal",
            superclass: nil,
            members: [MemberDeclaration(name: "name", type: .string)],
            constructor: ConstructorDeclaration(
                parameters: [Parameter(name: "n", type: .string)],
                body: [
                    .assignment(.fieldAccess(
                        Assignment.FieldAccess(object: .identifier("self"), field: "name"),
                        .identifier("n")
                    ))
                ]
            ),
            methods: []
        )

        // Define subclass Dog that extends Animal with additional member 'breed'
        let dogClass = ClassDeclaration(
            name: "Dog",
            superclass: "Animal",
            members: [MemberDeclaration(name: "breed", type: .string)],
            constructor: ConstructorDeclaration(
                parameters: [Parameter(name: "n", type: .string), Parameter(name: "b", type: .string)],
                body: [
                    .assignment(.fieldAccess(
                        Assignment.FieldAccess(object: .identifier("self"), field: "name"),
                        .identifier("n")
                    )),
                    .assignment(.fieldAccess(
                        Assignment.FieldAccess(object: .identifier("self"), field: "breed"),
                        .identifier("b")
                    ))
                ]
            ),
            methods: []
        )

        // Execute class declarations
        _ = try executor.executeStatement(.classDeclaration(animalClass))
        _ = try executor.executeStatement(.classDeclaration(dogClass))

        // Create Dog instance
        let dogInstance = try executor.callFunction("Dog", arguments: [.string("Buddy"), .string("Labrador")])

        // Verify the instance has both inherited 'name' and own 'breed' members
        guard case .instance(let inst) = dogInstance else {
            Issue.record("Expected instance value")
            return
        }

        #expect(inst.fields["name"] == .string("Buddy"))
        #expect(inst.fields["breed"] == .string("Labrador"))
    }

    @Test func testSubclassCanCallSuperclassMethod() throws {
        let env = Environment()
        let executor = StatementExecutor(environment: env)

        // Define superclass with a method
        let animalClass = ClassDeclaration(
            name: "Animal",
            superclass: nil,
            members: [MemberDeclaration(name: "age", type: .integer)],
            constructor: ConstructorDeclaration(
                parameters: [Parameter(name: "a", type: .integer)],
                body: [
                    .assignment(.fieldAccess(
                        Assignment.FieldAccess(object: .identifier("self"), field: "age"),
                        .identifier("a")
                    ))
                ]
            ),
            methods: [
                MethodDeclaration(
                    name: "getAge",
                    parameters: [],
                    returnType: .integer,
                    body: [
                        .returnStatement(ReturnStatement(
                            expression: .fieldAccess(.identifier("self"), "age")
                        ))
                    ]
                )
            ]
        )

        // Define subclass without overriding the method
        let dogClass = ClassDeclaration(
            name: "Dog",
            superclass: "Animal",
            members: [MemberDeclaration(name: "breed", type: .string)],
            constructor: ConstructorDeclaration(
                parameters: [Parameter(name: "a", type: .integer), Parameter(name: "b", type: .string)],
                body: [
                    .assignment(.fieldAccess(
                        Assignment.FieldAccess(object: .identifier("self"), field: "age"),
                        .identifier("a")
                    )),
                    .assignment(.fieldAccess(
                        Assignment.FieldAccess(object: .identifier("self"), field: "breed"),
                        .identifier("b")
                    ))
                ]
            ),
            methods: []
        )

        _ = try executor.executeStatement(.classDeclaration(animalClass))
        _ = try executor.executeStatement(.classDeclaration(dogClass))

        // Create Dog instance and verify it can use inherited method
        let dogInstance = try executor.callFunction("Dog", arguments: [.integer(3), .string("Labrador")])

        guard case .instance(let inst) = dogInstance else {
            Issue.record("Expected instance value")
            return
        }

        // Verify the inherited method exists in the class definition
        #expect(inst.classDefinition.methods["getAge"] != nil)
    }

    @Test func testSubclassMethodOverridesSuperclassMethod() throws {
        let env = Environment()
        let executor = StatementExecutor(environment: env)

        // Define superclass with a method that returns 1
        let animalClass = ClassDeclaration(
            name: "Animal",
            superclass: nil,
            members: [],
            constructor: nil,
            methods: [
                MethodDeclaration(
                    name: "speak",
                    parameters: [],
                    returnType: .integer,
                    body: [
                        .returnStatement(ReturnStatement(expression: .literal(.integer(1))))
                    ]
                )
            ]
        )

        // Define subclass that overrides the method to return 2
        let dogClass = ClassDeclaration(
            name: "Dog",
            superclass: "Animal",
            members: [],
            constructor: nil,
            methods: [
                MethodDeclaration(
                    name: "speak",
                    parameters: [],
                    returnType: .integer,
                    body: [
                        .returnStatement(ReturnStatement(expression: .literal(.integer(2))))
                    ]
                )
            ]
        )

        _ = try executor.executeStatement(.classDeclaration(animalClass))
        _ = try executor.executeStatement(.classDeclaration(dogClass))

        let dogInstance = try executor.callFunction("Dog", arguments: [])

        guard case .instance(let inst) = dogInstance else {
            Issue.record("Expected instance value")
            return
        }

        // Verify the subclass method overrides the superclass method
        let speakMethod = inst.classDefinition.methods["speak"]
        #expect(speakMethod != nil)

        // The method body should return 2 (subclass version), not 1 (superclass version)
        if let method = speakMethod {
            #expect(method.body.count == 1)
            if case .returnStatement(let ret) = method.body[0],
               case .literal(.integer(let value)) = ret.expression {
                #expect(value == 2)
            } else {
                Issue.record("Expected return statement with integer literal")
            }
        }
    }

    @Test func testMultiLevelInheritance() throws {
        let env = Environment()
        let executor = StatementExecutor(environment: env)

        // Define base class
        let animalClass = ClassDeclaration(
            name: "Animal",
            superclass: nil,
            members: [MemberDeclaration(name: "alive", type: .boolean)],
            constructor: nil,
            methods: []
        )

        // Define intermediate class
        let mammalClass = ClassDeclaration(
            name: "Mammal",
            superclass: "Animal",
            members: [MemberDeclaration(name: "warmBlooded", type: .boolean)],
            constructor: nil,
            methods: []
        )

        // Define leaf class
        let dogClass = ClassDeclaration(
            name: "Dog",
            superclass: "Mammal",
            members: [MemberDeclaration(name: "breed", type: .string)],
            constructor: nil,
            methods: []
        )

        _ = try executor.executeStatement(.classDeclaration(animalClass))
        _ = try executor.executeStatement(.classDeclaration(mammalClass))
        _ = try executor.executeStatement(.classDeclaration(dogClass))

        let dogInstance = try executor.callFunction("Dog", arguments: [])

        guard case .instance(let inst) = dogInstance else {
            Issue.record("Expected instance value")
            return
        }

        // Verify all inherited members are present
        #expect(inst.fields["alive"] != nil)
        #expect(inst.fields["warmBlooded"] != nil)
        #expect(inst.fields["breed"] != nil)
    }

    @Test func testCircularInheritanceDetection() throws {
        let env = Environment()
        let executor = StatementExecutor(environment: env)

        // Define class A that extends B
        let classA = ClassDeclaration(
            name: "A",
            superclass: "B",
            members: [MemberDeclaration(name: "valueA", type: .integer)],
            constructor: nil,
            methods: []
        )

        // Define class B that extends A (circular inheritance)
        let classB = ClassDeclaration(
            name: "B",
            superclass: "A",
            members: [MemberDeclaration(name: "valueB", type: .integer)],
            constructor: nil,
            methods: []
        )

        _ = try executor.executeStatement(.classDeclaration(classA))
        _ = try executor.executeStatement(.classDeclaration(classB))

        // Attempting to create an instance should throw a circular inheritance error
        do {
            _ = try executor.callFunction("A", arguments: [])
            Issue.record("Expected circular inheritance error")
        } catch let error as RuntimeError {
            #expect(error.description.contains("Circular inheritance"))
        }
    }

    @Test func testUndefinedSuperclassError() throws {
        let env = Environment()
        let executor = StatementExecutor(environment: env)

        // Define class that extends a non-existent superclass
        let dogClass = ClassDeclaration(
            name: "Dog",
            superclass: "NonExistentAnimal",
            members: [MemberDeclaration(name: "breed", type: .string)],
            constructor: nil,
            methods: []
        )

        _ = try executor.executeStatement(.classDeclaration(dogClass))

        // Attempting to create an instance should throw a superclass not found error
        do {
            _ = try executor.callFunction("Dog", arguments: [])
            Issue.record("Expected superclass not found error")
        } catch let error as RuntimeError {
            #expect(error.description.contains("Superclass"))
            #expect(error.description.contains("not found"))
        }
    }
}
