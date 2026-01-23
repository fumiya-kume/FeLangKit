import Foundation
import FeLangCore

/// Control flow signals during execution.
public enum ControlFlow: Equatable, Sendable {
    /// Normal execution continues
    case normal

    /// Return from function with optional value
    case returnValue(RuntimeValue?)

    /// Break out of loop
    case breakLoop

    /// Continue to next iteration
    case continueLoop
}

/// Executes statements and manages control flow.
public final class StatementExecutor: @unchecked Sendable {
    /// The environment for variable storage
    private let environment: Environment

    /// Expression evaluator
    private var evaluator: ExpressionEvaluator!

    /// Loop depth for break/continue validation
    private var loopDepth: Int = 0

    // MARK: - Initialization

    public init(environment: Environment) {
        self.environment = environment
        self.evaluator = ExpressionEvaluator(environment: environment) { [weak self] name, args in
            guard let self = self else { throw RuntimeError.generic(message: "Executor deallocated") }
            return try self.callFunction(name, arguments: args)
        }
    }

    // MARK: - Main Execution

    /// Executes a list of statements.
    public func execute(_ statements: [Statement]) throws -> ControlFlow {
        for statement in statements {
            let result = try executeStatement(statement)
            switch result {
            case .normal:
                continue
            case .returnValue, .breakLoop, .continueLoop:
                return result
            }
        }
        return .normal
    }

    /// Executes a single statement.
    public func executeStatement(_ statement: Statement) throws -> ControlFlow {
        switch statement {
        case .variableDeclaration(let decl):
            try executeVariableDeclaration(decl)
            return .normal

        case .constantDeclaration(let decl):
            try executeConstantDeclaration(decl)
            return .normal

        case .assignment(let assignment):
            try executeAssignment(assignment)
            return .normal

        case .ifStatement(let ifStmt):
            return try executeIfStatement(ifStmt)

        case .whileStatement(let whileStmt):
            return try executeWhileStatement(whileStmt)

        case .forStatement(let forStmt):
            return try executeForStatement(forStmt)

        case .functionDeclaration(let funcDecl):
            try executeFunctionDeclaration(funcDecl)
            return .normal

        case .procedureDeclaration(let procDecl):
            try executeProcedureDeclaration(procDecl)
            return .normal

        case .returnStatement(let returnStmt):
            return try executeReturnStatement(returnStmt)

        case .expressionStatement(let expr):
            _ = try evaluator.evaluate(expr)
            return .normal

        case .breakStatement:
            guard loopDepth > 0 else {
                throw RuntimeError.breakOutsideLoop
            }
            return .breakLoop

        case .continueStatement:
            guard loopDepth > 0 else {
                throw RuntimeError.continueOutsideLoop
            }
            return .continueLoop

        case .block(let statements):
            try environment.pushScope()
            defer { environment.popScope() }
            return try execute(statements)
        }
    }

    // MARK: - Declaration Execution

    private func executeVariableDeclaration(_ decl: VariableDeclaration) throws {
        let value: RuntimeValue
        if let initialValue = decl.initialValue {
            value = try evaluator.evaluate(initialValue)
        } else {
            value = defaultValue(for: decl.type)
        }
        environment.define(decl.name, value: value, isConstant: false)
    }

    private func executeConstantDeclaration(_ decl: ConstantDeclaration) throws {
        let value = try evaluator.evaluate(decl.initialValue)
        environment.define(decl.name, value: value, isConstant: true)
    }

    private func executeFunctionDeclaration(_ decl: FunctionDeclaration) throws {
        let parameterNames = decl.parameters.map { $0.name }
        let captured = environment.captureEnvironmentWithConstants()
        let functionValue = FunctionValue(
            name: decl.name,
            parameters: parameterNames,
            body: decl.body,
            capturedEnvironment: captured.values,
            capturedConstants: captured.constants,
            returnType: decl.returnType
        )
        environment.define(decl.name, value: .function(functionValue))
    }

    private func executeProcedureDeclaration(_ decl: ProcedureDeclaration) throws {
        let parameterNames = decl.parameters.map { $0.name }
        let captured = environment.captureEnvironmentWithConstants()
        let procedureValue = ProcedureValue(
            name: decl.name,
            parameters: parameterNames,
            body: decl.body,
            capturedEnvironment: captured.values,
            capturedConstants: captured.constants
        )
        environment.define(decl.name, value: .procedure(procedureValue))
    }

    // MARK: - Assignment Execution

    private func executeAssignment(_ assignment: Assignment) throws {
        switch assignment {
        case .variable(let name, let expr):
            let value = try evaluator.evaluate(expr)
            try environment.assign(name, value: value)

        case .arrayElement(let arrayAccess, let expr):
            let value = try evaluator.evaluate(expr)
            try assignArrayElement(arrayAccess, value: value)
        }
    }

    private func assignArrayElement(_ access: Assignment.ArrayAccess, value: RuntimeValue) throws {
        guard case .identifier(let arrayName) = access.array else {
            throw RuntimeError.generic(message: "Cannot assign to complex array expression")
        }

        let indexValue = try evaluator.evaluate(access.index)
        guard case .integer(let index) = indexValue else {
            throw RuntimeError.typeMismatch(
                expected: "integer",
                actual: indexValue.typeName,
                operation: "array index"
            )
        }

        let arrayValue = try environment.get(arrayName)
        guard case .array(var elements) = arrayValue else {
            throw RuntimeError.typeMismatch(
                expected: "array",
                actual: arrayValue.typeName,
                operation: "array assignment"
            )
        }

        guard index >= 0, index < elements.count else {
            throw RuntimeError.indexOutOfBounds(index: index, size: elements.count)
        }

        elements[index] = value
        try environment.assign(arrayName, value: .array(elements))
    }

    // MARK: - Control Flow Execution

    private func executeIfStatement(_ ifStmt: IfStatement) throws -> ControlFlow {
        let condition = try evaluator.evaluate(ifStmt.condition)

        if condition.isTruthy {
            try environment.pushScope()
            defer { environment.popScope() }
            return try execute(ifStmt.thenBody)
        }

        for elseIf in ifStmt.elseIfs {
            let elseIfCondition = try evaluator.evaluate(elseIf.condition)
            if elseIfCondition.isTruthy {
                try environment.pushScope()
                defer { environment.popScope() }
                return try execute(elseIf.body)
            }
        }

        if let elseBody = ifStmt.elseBody {
            try environment.pushScope()
            defer { environment.popScope() }
            return try execute(elseBody)
        }

        return .normal
    }

    private func executeWhileStatement(_ whileStmt: WhileStatement) throws -> ControlFlow {
        loopDepth += 1
        defer { loopDepth -= 1 }

        while try evaluator.evaluate(whileStmt.condition).isTruthy {
            try environment.pushScope()
            defer { environment.popScope() }
            let result = try execute(whileStmt.body)

            switch result {
            case .breakLoop:
                return .normal
            case .continueLoop:
                continue
            case .returnValue:
                return result
            case .normal:
                continue
            }
        }

        return .normal
    }

    private func executeForStatement(_ forStmt: ForStatement) throws -> ControlFlow {
        switch forStmt {
        case .range(let rangeFor):
            return try executeRangeFor(rangeFor)
        case .forEach(let forEach):
            return try executeForEach(forEach)
        }
    }

    private func executeRangeFor(_ rangeFor: ForStatement.RangeFor) throws -> ControlFlow {
        loopDepth += 1
        defer { loopDepth -= 1 }

        let startValue = try evaluator.evaluate(rangeFor.start)
        let endValue = try evaluator.evaluate(rangeFor.end)

        guard case .integer(let start) = startValue,
              case .integer(let end) = endValue else {
            throw RuntimeError.typeMismatch(
                expected: "integer",
                actual: "\(startValue.typeName) and \(endValue.typeName)",
                operation: "for loop range"
            )
        }

        var step = 1
        if let stepExpr = rangeFor.step {
            let stepValue = try evaluator.evaluate(stepExpr)
            guard case .integer(let stepInt) = stepValue, stepInt > 0 else {
                throw RuntimeError.typeMismatch(
                    expected: "positive integer",
                    actual: stepValue.typeName,
                    operation: "for loop step"
                )
            }
            step = stepInt
        }
        let range = start <= end ? stride(from: start, through: end, by: step)
                                 : stride(from: start, through: end, by: -step)

        for currentValue in range {
            try environment.pushScope()
            defer { environment.popScope() }
            environment.define(rangeFor.variable, value: .integer(currentValue))

            let result = try execute(rangeFor.body)

            switch result {
            case .breakLoop:
                return .normal
            case .continueLoop:
                continue
            case .returnValue:
                return result
            case .normal:
                continue
            }
        }

        return .normal
    }

    private func executeForEach(_ forEach: ForStatement.ForEachLoop) throws -> ControlFlow {
        loopDepth += 1
        defer { loopDepth -= 1 }

        let iterable = try evaluator.evaluate(forEach.iterable)

        guard case .array(let elements) = iterable else {
            throw RuntimeError.typeMismatch(
                expected: "array",
                actual: iterable.typeName,
                operation: "for-each loop"
            )
        }

        for element in elements {
            try environment.pushScope()
            defer { environment.popScope() }
            environment.define(forEach.variable, value: element)

            let result = try execute(forEach.body)

            switch result {
            case .breakLoop:
                return .normal
            case .continueLoop:
                continue
            case .returnValue:
                return result
            case .normal:
                continue
            }
        }

        return .normal
    }

    private func executeReturnStatement(_ returnStmt: ReturnStatement) throws -> ControlFlow {
        if let expr = returnStmt.expression {
            let value = try evaluator.evaluate(expr)
            return .returnValue(value)
        }
        return .returnValue(nil)
    }

    // MARK: - Function Calling

    public func callFunction(_ name: String, arguments: [RuntimeValue]) throws -> RuntimeValue {
        guard let callable = environment.lookup(name) else {
            throw RuntimeError.undefinedFunction(name: name)
        }

        switch callable {
        case .function(let functionValue):
            return try callFunctionValue(functionValue, arguments: arguments)
        case .procedure(let procedureValue):
            try callProcedureValue(procedureValue, arguments: arguments)
            return .null
        default:
            throw RuntimeError.notCallable(type: callable.typeName)
        }
    }

    private func callFunctionValue(
        _ function: FunctionValue,
        arguments: [RuntimeValue]
    ) throws -> RuntimeValue {
        guard arguments.count == function.parameters.count else {
            throw RuntimeError.wrongArgumentCount(
                function: function.name,
                expected: function.parameters.count,
                actual: arguments.count
            )
        }

        try environment.enterCall()
        defer { environment.exitCall() }

        try environment.pushScope()
        defer { environment.popScope() }

        // Import captured environment with constant metadata preserved
        environment.importVariables(function.capturedEnvironment, constants: function.capturedConstants)

        // Bind parameters
        for (param, arg) in zip(function.parameters, arguments) {
            environment.define(param, value: arg)
        }

        // Execute body
        let result = try execute(function.body)

        switch result {
        case .returnValue(let value):
            return value ?? .null
        default:
            throw RuntimeError.missingReturnValue(function: function.name)
        }
    }

    private func callProcedureValue(
        _ procedure: ProcedureValue,
        arguments: [RuntimeValue]
    ) throws {
        guard arguments.count == procedure.parameters.count else {
            throw RuntimeError.wrongArgumentCount(
                function: procedure.name,
                expected: procedure.parameters.count,
                actual: arguments.count
            )
        }

        try environment.enterCall()
        defer { environment.exitCall() }

        try environment.pushScope()
        defer { environment.popScope() }

        // Import captured environment with constant metadata preserved
        environment.importVariables(procedure.capturedEnvironment, constants: procedure.capturedConstants)

        // Bind parameters
        for (param, arg) in zip(procedure.parameters, arguments) {
            environment.define(param, value: arg)
        }

        // Execute body
        let result = try execute(procedure.body)
        if case .returnValue(let value) = result, value != nil {
            throw RuntimeError.returnInVoidContext
        }
    }

    // MARK: - Helper Methods

    private func defaultValue(for type: DataType) -> RuntimeValue {
        switch type {
        case .integer:
            return .integer(0)
        case .real:
            return .real(0.0)
        case .string:
            return .string("")
        case .character:
            return .character(" ")
        case .boolean:
            return .boolean(false)
        case .array:
            return .array([])
        case .record:
            return .record([:])
        }
    }
}
