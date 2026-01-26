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

    /// Function depth for return validation
    private var functionDepth: Int = 0

    /// External function resolver for standard library functions
    private var externalFunctionResolver: (@Sendable (String, [RuntimeValue]) throws -> RuntimeValue)?

    // MARK: - Initialization

    public init(environment: Environment) {
        self.environment = environment
        self.evaluator = ExpressionEvaluator(environment: environment) { [weak self] name, args in
            guard let self = self else { throw RuntimeError.generic(message: "Executor deallocated") }
            return try self.callFunction(name, arguments: args)
        }
    }

    /// Sets the external function resolver for standard library functions
    public func setExternalFunctionResolver(
        _ resolver: @escaping @Sendable (String, [RuntimeValue]) throws -> RuntimeValue
    ) {
        self.externalFunctionResolver = resolver
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

        case .doWhileStatement(let doWhileStmt):
            return try executeDoWhileStatement(doWhileStmt)

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

        case .recordDeclaration(let decl):
            executeRecordDeclaration(decl)
            return .normal

        case .classDeclaration(let decl):
            executeClassDeclaration(decl)
            return .normal
        }
    }

    // MARK: - Declaration Execution

    private func executeRecordDeclaration(_ decl: RecordDeclaration) {
        environment.defineRecord(decl.name, fields: decl.fields)
    }

    private func executeClassDeclaration(_ decl: ClassDeclaration) {
        var members: [String: DataType] = [:]
        for member in decl.members {
            members[member.name] = member.type
        }

        var constructorParams: [String] = []
        var constructorParamTypes: [DataType] = []
        var constructorBody: [Statement] = []

        if let constructor = decl.constructor {
            constructorParams = constructor.parameters.map { $0.name }
            constructorParamTypes = constructor.parameters.map { $0.type }
            constructorBody = constructor.body
        }

        var methods: [String: MethodDefinition] = [:]
        for method in decl.methods {
            let methodDef = MethodDefinition(
                name: method.name,
                parameters: method.parameters.map { $0.name },
                parameterTypes: method.parameters.map { $0.type },
                returnType: method.returnType,
                body: method.body
            )
            methods[method.name] = methodDef
        }

        let classDef = ClassDefinition(
            name: decl.name,
            superclassName: decl.superclass,
            members: members,
            constructorParameters: constructorParams,
            constructorParameterTypes: constructorParamTypes,
            constructorBody: constructorBody,
            methods: methods
        )

        environment.defineClass(decl.name, definition: classDef)
    }

    private func executeVariableDeclaration(_ decl: VariableDeclaration) throws {
        let value: RuntimeValue
        let isInitialized: Bool
        if let initialValue = decl.initialValue {
            value = try evaluator.evaluate(initialValue)
            // Validate type of initial value matches declaration
            try validateType(value, expected: decl.type, context: "variable '\(decl.name)' initialization")
            isInitialized = true
        } else {
            value = defaultValue(for: decl.type)
            isInitialized = false
        }
        environment.define(decl.name, value: value, isConstant: false, type: decl.type, isInitialized: isInitialized)
    }

    private func executeConstantDeclaration(_ decl: ConstantDeclaration) throws {
        let value = try evaluator.evaluate(decl.initialValue)
        // Validate type of initial value matches declaration
        try validateType(value, expected: decl.type, context: "constant '\(decl.name)' initialization")
        environment.define(decl.name, value: value, isConstant: true, type: decl.type)
    }

    private func executeFunctionDeclaration(_ decl: FunctionDeclaration) throws {
        let parameterNames = decl.parameters.map { $0.name }
        let parameterTypes = decl.parameters.map { $0.type }
        let captured = environment.captureEnvironmentWithConstants()
        let functionValue = FunctionValue(
            name: decl.name,
            parameters: parameterNames,
            parameterTypes: parameterTypes,
            body: decl.body,
            capturedEnvironment: captured.values,
            capturedConstants: captured.constants,
            capturedTypes: captured.types,
            capturedUninitialized: captured.uninitialized,
            returnType: decl.returnType
        )
        environment.define(decl.name, value: .function(functionValue))
    }

    private func executeProcedureDeclaration(_ decl: ProcedureDeclaration) throws {
        let parameterNames = decl.parameters.map { $0.name }
        let parameterTypes = decl.parameters.map { $0.type }
        let captured = environment.captureEnvironmentWithConstants()
        let procedureValue = ProcedureValue(
            name: decl.name,
            parameters: parameterNames,
            parameterTypes: parameterTypes,
            body: decl.body,
            capturedEnvironment: captured.values,
            capturedConstants: captured.constants,
            capturedTypes: captured.types,
            capturedUninitialized: captured.uninitialized
        )
        environment.define(decl.name, value: .procedure(procedureValue))
    }

    // MARK: - Assignment Execution

    private func executeAssignment(_ assignment: Assignment) throws {
        switch assignment {
        case .variable(let name, let expr):
            let value = try evaluator.evaluate(expr)
            // Validate type if variable has a declared type
            if let expectedType = environment.lookupType(name) {
                try validateType(value, expected: expectedType, context: "assignment to '\(name)'")
            }
            try environment.assign(name, value: value)

        case .arrayElement(let arrayAccess, let expr):
            let value = try evaluator.evaluate(expr)
            try assignArrayElement(arrayAccess, value: value)

        case .fieldAccess(let fieldAccess, let expr):
            let value = try evaluator.evaluate(expr)
            try assignFieldAccess(fieldAccess, value: value)
        }
    }

    private func assignFieldAccess(_ access: Assignment.FieldAccess, value: RuntimeValue) throws {
        let objectValue = try evaluator.evaluate(access.object)

        switch objectValue {
        case .instance(var inst):
            // Validate field exists
            guard inst.fields[access.field] != nil else {
                throw RuntimeError.invalidFieldAccess(field: access.field, type: inst.className)
            }

            // Validate type if member has a declared type
            if let expectedType = inst.classDefinition.members[access.field] {
                try validateType(value, expected: expectedType, context: "assignment to '\(access.field)'")
            }

            inst.fields[access.field] = value

            // Update the instance in the environment
            switch access.object {
            case .identifier(let name):
                try environment.assign(name, value: .instance(inst))
            default:
                throw RuntimeError.generic(message: "Cannot assign to field of complex expression")
            }

        case .record(var fields):
            guard fields[access.field] != nil else {
                throw RuntimeError.invalidFieldAccess(field: access.field, type: "record")
            }
            fields[access.field] = value

            switch access.object {
            case .identifier(let name):
                try environment.assign(name, value: .record(fields))
            default:
                throw RuntimeError.generic(message: "Cannot assign to field of complex expression")
            }

        default:
            throw RuntimeError.invalidFieldAccess(field: access.field, type: objectValue.typeName)
        }
    }

    private func assignArrayElement(_ access: Assignment.ArrayAccess, value: RuntimeValue) throws {
        let indexValue = try evaluator.evaluate(access.index)
        guard case .integer(let index) = indexValue else {
            throw RuntimeError.typeMismatch(
                expected: "integer",
                actual: indexValue.typeName,
                operation: "array index"
            )
        }

        switch access.array {
        case .identifier(let arrayName):
            // Simple case: arr[i] ← value
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

            // Validate type matches existing element type
            if let existingElement = elements.first {
                if let existingType = inferDataType(from: existingElement),
                   let valueType = inferDataType(from: value) {
                    if !typesMatch(valueType, expected: existingType) {
                        throw RuntimeError.typeMismatch(
                            expected: String(describing: existingType),
                            actual: String(describing: valueType),
                            operation: "array element assignment"
                        )
                    }
                } else if existingElement.typeName != value.typeName {
                    throw RuntimeError.typeMismatch(
                        expected: existingElement.typeName,
                        actual: value.typeName,
                        operation: "array element assignment"
                    )
                }
            }

            elements[index] = value
            try environment.assign(arrayName, value: .array(elements))

        case .arrayAccess(let innerArray, let innerIndex):
            // Nested case: arr[i][j] ← value
            // First, get the inner array and modify it
            let innerArrayValue = try evaluator.evaluate(.arrayAccess(innerArray, innerIndex))
            guard case .array(var innerElements) = innerArrayValue else {
                throw RuntimeError.typeMismatch(
                    expected: "array",
                    actual: innerArrayValue.typeName,
                    operation: "nested array assignment"
                )
            }

            guard index >= 0, index < innerElements.count else {
                throw RuntimeError.indexOutOfBounds(index: index, size: innerElements.count)
            }

            // Validate type matches existing element type
            if let existingElement = innerElements.first {
                if let existingType = inferDataType(from: existingElement),
                   let valueType = inferDataType(from: value) {
                    if !typesMatch(valueType, expected: existingType) {
                        throw RuntimeError.typeMismatch(
                            expected: String(describing: existingType),
                            actual: String(describing: valueType),
                            operation: "nested array element assignment"
                        )
                    }
                } else if existingElement.typeName != value.typeName {
                    throw RuntimeError.typeMismatch(
                        expected: existingElement.typeName,
                        actual: value.typeName,
                        operation: "nested array element assignment"
                    )
                }
            }

            innerElements[index] = value

            // Now assign the modified inner array back
            let innerAccess = Assignment.ArrayAccess(array: innerArray, index: innerIndex)
            try assignArrayElement(innerAccess, value: .array(innerElements))

        default:
            throw RuntimeError.generic(message: "Cannot assign to complex array expression")
        }
    }

    // MARK: - Control Flow Execution

    private func executeIfStatement(_ ifStmt: IfStatement) throws -> ControlFlow {
        let condition = try evaluator.evaluate(ifStmt.condition)
        guard case .boolean(let boolValue) = condition else {
            throw RuntimeError.typeMismatch(
                expected: "Boolean",
                actual: condition.typeName,
                operation: "if condition"
            )
        }

        if boolValue {
            try environment.pushScope()
            defer { environment.popScope() }
            return try execute(ifStmt.thenBody)
        }

        for elseIf in ifStmt.elseIfs {
            let elseIfCondition = try evaluator.evaluate(elseIf.condition)
            guard case .boolean(let elseIfBoolValue) = elseIfCondition else {
                throw RuntimeError.typeMismatch(
                    expected: "Boolean",
                    actual: elseIfCondition.typeName,
                    operation: "elif condition"
                )
            }
            if elseIfBoolValue {
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

        while true {
            let condition = try evaluator.evaluate(whileStmt.condition)
            guard case .boolean(let boolValue) = condition else {
                throw RuntimeError.typeMismatch(
                    expected: "Boolean",
                    actual: condition.typeName,
                    operation: "while condition"
                )
            }
            guard boolValue else { break }

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

    private func executeDoWhileStatement(_ doWhileStmt: DoWhileStatement) throws -> ControlFlow {
        loopDepth += 1
        defer { loopDepth -= 1 }

        repeat {
            // Execute body in its own scope (consistent with while/for loops)
            // Use do-catch to ensure popScope is called even on exception
            try environment.pushScope()
            let result: ControlFlow
            do {
                result = try execute(doWhileStmt.body)
            } catch {
                environment.popScope()
                throw error
            }
            environment.popScope()

            switch result {
            case .breakLoop:
                return .normal
            case .continueLoop:
                break
            case .returnValue:
                return result
            case .normal:
                break
            }

            // Evaluate condition outside the body scope (consistent with while loops)
            let condition = try evaluator.evaluate(doWhileStmt.condition)
            guard case .boolean(let boolValue) = condition else {
                throw RuntimeError.typeMismatch(
                    expected: "Boolean",
                    actual: condition.typeName,
                    operation: "do-while condition"
                )
            }
            guard boolValue else { return .normal }
        } while true
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
        var hasExplicitStep = false
        if let stepExpr = rangeFor.step {
            hasExplicitStep = true
            let stepValue = try evaluator.evaluate(stepExpr)
            guard case .integer(let stepInt) = stepValue else {
                throw RuntimeError.typeMismatch(
                    expected: "integer",
                    actual: stepValue.typeName,
                    operation: "for loop step"
                )
            }
            guard stepInt != 0 else {
                throw RuntimeError.generic(message: "For loop step cannot be zero")
            }
            step = stepInt
        }

        // Create range based on step direction and explicit step flag
        let range: StrideThrough<Int>
        if hasExplicitStep {
            // With explicit step, use it directly (user controls direction)
            range = stride(from: start, through: end, by: step)
        } else {
            // Without explicit step, only forward iteration
            if start <= end {
                range = stride(from: start, through: end, by: 1)
            } else {
                // Empty range - don't execute loop when end < start without explicit step.
                // Using a dummy stride here is intentional: this range iterates zero times.
                range = stride(from: 0, through: -1, by: 1)
            }
        }

        for currentValue in range {
            try environment.pushScope()
            defer { environment.popScope() }
            environment.define(rangeFor.variable, value: .integer(currentValue), type: .integer)

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
            let elementType = inferDataType(from: element)
            environment.define(forEach.variable, value: element, type: elementType)

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
        guard functionDepth > 0 else {
            throw RuntimeError.generic(message: "Return statement outside of function")
        }
        if let expr = returnStmt.expression {
            let value = try evaluator.evaluate(expr)
            return .returnValue(value)
        }
        return .returnValue(nil)
    }

    // MARK: - Function Calling

    public func callFunction(_ name: String, arguments: [RuntimeValue]) throws -> RuntimeValue {
        // First check user-defined functions in environment
        if let callable = environment.lookup(name) {
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

        // Check if this is a class instantiation
        if let classDef = environment.lookupClassDefinition(name) {
            return try createInstance(classDef, arguments: arguments)
        }

        // Then try external function resolver (for standard library functions)
        if let resolver = externalFunctionResolver {
            return try resolver(name, arguments)
        }

        throw RuntimeError.undefinedFunction(name: name)
    }

    private func createInstance(
        _ classDef: ClassDefinition,
        arguments: [RuntimeValue]
    ) throws -> RuntimeValue {
        // Validate constructor argument count
        guard arguments.count == classDef.constructorParameters.count else {
            throw RuntimeError.wrongArgumentCount(
                function: classDef.name,
                expected: classDef.constructorParameters.count,
                actual: arguments.count
            )
        }

        // Validate constructor parameter types
        if !classDef.constructorParameterTypes.isEmpty {
            for (index, (param, arg)) in zip(classDef.constructorParameters, arguments).enumerated() {
                guard index < classDef.constructorParameterTypes.count else { continue }
                let expectedType = classDef.constructorParameterTypes[index]
                try validateType(arg, expected: expectedType, context: "parameter '\(param)' of '\(classDef.name)' constructor")
            }
        }

        // Initialize member fields with default values, starting with inherited members
        var fields: [String: RuntimeValue] = [:]

        // Merge superclass members first (inheritance)
        if let superclassName = classDef.superclassName {
            guard let superclassDef = environment.lookupClassDefinition(superclassName) else {
                throw RuntimeError.generic(message: "Superclass '\(superclassName)' not found for class '\(classDef.name)'")
            }
            // Recursively collect all inherited members from the superclass chain
            var visited: Set<String> = [classDef.name]
            let inheritedMembers = try collectInheritedMembers(from: superclassDef, visited: &visited)
            for (memberName, memberType) in inheritedMembers {
                fields[memberName] = defaultValue(for: memberType)
            }
        }

        // Add this class's own members (may override inherited members)
        for (memberName, memberType) in classDef.members {
            fields[memberName] = defaultValue(for: memberType)
        }

        // Create the instance with merged class definition for method resolution
        var mergedVisited: Set<String> = []
        let mergedClassDef = try createMergedClassDefinition(classDef, visited: &mergedVisited)
        var instance = InstanceValue(
            className: classDef.name,
            classDefinition: mergedClassDef,
            fields: fields
        )

        // Execute constructor body if present
        if !classDef.constructorBody.isEmpty {
            try environment.enterCall()
            defer { environment.exitCall() }

            functionDepth += 1
            defer { functionDepth -= 1 }

            try environment.pushScope()
            defer { environment.popScope() }

            // Bind constructor parameters
            for (index, (param, arg)) in zip(classDef.constructorParameters, arguments).enumerated() {
                let paramType = index < classDef.constructorParameterTypes.count
                    ? classDef.constructorParameterTypes[index]
                    : nil
                environment.define(param, value: arg, type: paramType)
            }

            // Define 'self' as the instance being constructed
            environment.define("self", value: .instance(instance))

            // Execute constructor body
            _ = try execute(classDef.constructorBody)

            // Retrieve the potentially modified 'self' instance
            if case .instance(let modifiedInstance) = try environment.get("self") {
                instance = modifiedInstance
            }
        }

        return .instance(instance)
    }

    /// Collects all inherited members from a class and its superclass chain.
    /// Uses a visited set to detect circular inheritance.
    private func collectInheritedMembers(
        from classDef: ClassDefinition,
        visited: inout Set<String>
    ) throws -> [String: DataType] {
        // Check for circular inheritance
        guard !visited.contains(classDef.name) else {
            throw RuntimeError.generic(message: "Circular inheritance detected involving class '\(classDef.name)'")
        }
        visited.insert(classDef.name)

        var members: [String: DataType] = [:]

        // First collect from superclass (if any)
        if let superclassName = classDef.superclassName,
           let superclassDef = environment.lookupClassDefinition(superclassName) {
            let superMembers = try collectInheritedMembers(from: superclassDef, visited: &visited)
            for (name, type) in superMembers {
                members[name] = type
            }
        }

        // Then add this class's members (may override)
        for (name, type) in classDef.members {
            members[name] = type
        }

        return members
    }

    /// Creates a merged class definition that includes inherited methods for method resolution.
    /// Subclass methods take priority over superclass methods (method override).
    /// Uses a visited set to detect circular inheritance.
    private func createMergedClassDefinition(
        _ classDef: ClassDefinition,
        visited: inout Set<String>
    ) throws -> ClassDefinition {
        // Check for circular inheritance
        guard !visited.contains(classDef.name) else {
            throw RuntimeError.generic(message: "Circular inheritance detected involving class '\(classDef.name)'")
        }
        visited.insert(classDef.name)

        var mergedMethods: [String: MethodDefinition] = [:]
        var mergedMembers: [String: DataType] = [:]

        // Collect methods and members from superclass chain first
        if let superclassName = classDef.superclassName,
           let superclassDef = environment.lookupClassDefinition(superclassName) {
            let mergedSuperclass = try createMergedClassDefinition(superclassDef, visited: &visited)
            mergedMethods = mergedSuperclass.methods
            mergedMembers = mergedSuperclass.members
        }

        // Add this class's members (may override inherited)
        for (name, type) in classDef.members {
            mergedMembers[name] = type
        }

        // Add this class's methods (may override inherited)
        for (name, method) in classDef.methods {
            mergedMethods[name] = method
        }

        return ClassDefinition(
            name: classDef.name,
            superclassName: classDef.superclassName,
            members: mergedMembers,
            constructorParameters: classDef.constructorParameters,
            constructorParameterTypes: classDef.constructorParameterTypes,
            constructorBody: classDef.constructorBody,
            methods: mergedMethods
        )
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

        // Validate parameter types
        if !function.parameterTypes.isEmpty {
            for (index, (param, arg)) in zip(function.parameters, arguments).enumerated() {
                guard index < function.parameterTypes.count else { continue }
                let expectedType = function.parameterTypes[index]
                try validateType(arg, expected: expectedType, context: "parameter '\(param)' of '\(function.name)'")
            }
        }

        try environment.enterCall()
        defer { environment.exitCall() }

        functionDepth += 1
        defer { functionDepth -= 1 }

        try environment.pushScope()
        defer { environment.popScope() }

        // Import captured environment with constant metadata, type information, and initialization status preserved
        let capturedEnv = Environment.CapturedEnvironment(
            values: function.capturedEnvironment,
            constants: function.capturedConstants,
            types: function.capturedTypes,
            uninitialized: function.capturedUninitialized
        )
        environment.importVariables(capturedEnv)

        // Bind parameters with their types
        for (index, (param, arg)) in zip(function.parameters, arguments).enumerated() {
            let paramType = index < function.parameterTypes.count ? function.parameterTypes[index] : nil
            environment.define(param, value: arg, type: paramType)
        }

        // Execute body
        let result = try execute(function.body)

        switch result {
        case .returnValue(let value):
            let returnValue = value ?? .null
            // Validate return type
            if let expectedType = function.returnType {
                try validateType(returnValue, expected: expectedType, context: "return value of '\(function.name)'")
            }
            return returnValue
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

        // Validate parameter types
        if !procedure.parameterTypes.isEmpty {
            for (index, (param, arg)) in zip(procedure.parameters, arguments).enumerated() {
                guard index < procedure.parameterTypes.count else { continue }
                let expectedType = procedure.parameterTypes[index]
                try validateType(arg, expected: expectedType, context: "parameter '\(param)' of '\(procedure.name)'")
            }
        }

        try environment.enterCall()
        defer { environment.exitCall() }

        functionDepth += 1
        defer { functionDepth -= 1 }

        try environment.pushScope()
        defer { environment.popScope() }

        // Import captured environment with constant metadata, type information, and initialization status preserved
        let capturedEnv = Environment.CapturedEnvironment(
            values: procedure.capturedEnvironment,
            constants: procedure.capturedConstants,
            types: procedure.capturedTypes,
            uninitialized: procedure.capturedUninitialized
        )
        environment.importVariables(capturedEnv)

        // Bind parameters with their types
        for (index, (param, arg)) in zip(procedure.parameters, arguments).enumerated() {
            let paramType = index < procedure.parameterTypes.count ? procedure.parameterTypes[index] : nil
            environment.define(param, value: arg, type: paramType)
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

    private func inferDataType(from value: RuntimeValue) -> DataType? {
        switch value {
        case .integer: return .integer
        case .real: return .real
        case .string: return .string
        case .character: return .character
        case .boolean: return .boolean
        case .array(let elements):
            // Infer element type from first element if available
            if let first = elements.first, let elementType = inferDataType(from: first) {
                return .array(elementType)
            }
            return nil
        case .record:
            // Record type name cannot be inferred from runtime value
            return nil
        case .function, .procedure, .null, .classDefinition, .instance, .undefined:
            return nil
        }
    }

    private func validateType(_ value: RuntimeValue, expected: DataType, context: String) throws {
        let matches: Bool
        switch (expected, value) {
        case (_, .undefined):
            // Undefined is compatible with any type (matches semantic analyzer behavior)
            matches = true
        case (.integer, .integer):
            matches = true
        case (.real, .real):
            matches = true
        case (.real, .integer):
            // Integer can be promoted to real
            matches = true
        case (.string, .string):
            matches = true
        case (.character, .character):
            matches = true
        case (.boolean, .boolean):
            matches = true
        case (.array(let expectedElementType), .array(let elements)):
            if elements.isEmpty {
                // Empty array matches any element type
                matches = true
            } else {
                let mismatchIndices = validateArrayElements(elements, expectedElementType: expectedElementType)
                if mismatchIndices.isEmpty {
                    matches = true
                } else {
                    // Throw with detailed error message including mismatched indices
                    let mismatchedElement = elements[mismatchIndices[0]]
                    let actualTypeDesc = inferDataType(from: mismatchedElement)
                        .map { String(describing: $0) }
                        ?? mismatchedElement.typeName
                    throw RuntimeError.typeMismatch(
                        expected: "array of \(expectedElementType)",
                        actual: "array containing \(actualTypeDesc) at indices \(mismatchIndices)",
                        operation: context
                    )
                }
            }
        case (.record(let expectedName), .record(let fields)):
            // Look up record definition and validate field types
            if let definition = environment.lookupRecordDefinition(expectedName) {
                let (isValid, errorDetail) = validateRecordFields(fields, definition: definition)
                if !isValid {
                    throw RuntimeError.typeMismatch(
                        expected: "record \(expectedName)",
                        actual: errorDetail ?? "invalid record",
                        operation: context
                    )
                }
                matches = true
            } else {
                // Undefined record type is a type error
                throw RuntimeError.typeMismatch(
                    expected: "record \(expectedName)",
                    actual: "undefined record type",
                    operation: context
                )
            }
        default:
            matches = false
        }

        guard matches else {
            throw RuntimeError.typeMismatch(
                expected: String(describing: expected),
                actual: value.typeName,
                operation: context
            )
        }
    }

    /// Checks if an actual DataType matches an expected DataType, including integer → real promotion.
    /// This method handles recursive array type checking.
    private func typesMatch(_ actual: DataType, expected: DataType) -> Bool {
        switch (expected, actual) {
        case (.integer, .integer):
            return true
        case (.real, .real):
            return true
        case (.real, .integer):
            // Integer can be promoted to real
            return true
        case (.string, .string):
            return true
        case (.character, .character):
            return true
        case (.boolean, .boolean):
            return true
        case (.array(let expectedElem), .array(let actualElem)):
            // Recursively check element types
            return typesMatch(actualElem, expected: expectedElem)
        case (.record(let expectedName), .record(let actualName)):
            return expectedName == actualName
        default:
            return false
        }
    }

    /// Validates all elements in an array against the expected element type.
    /// Returns indices of elements that don't match the expected type.
    private func validateArrayElements(
        _ elements: [RuntimeValue],
        expectedElementType: DataType
    ) -> [Int] {
        var mismatchIndices: [Int] = []
        for (index, element) in elements.enumerated() {
            if case .undefined = element {
                // Undefined is compatible with any type
                continue
            }
            if let actualType = inferDataType(from: element) {
                if !typesMatch(actualType, expected: expectedElementType) {
                    mismatchIndices.append(index)
                }
            } else {
                // Cannot infer type (e.g., function, procedure, null)
                mismatchIndices.append(index)
            }
        }
        return mismatchIndices
    }

    /// Validates all fields in a record against the expected field types.
    /// - Parameters:
    ///   - fields: The actual record field values
    ///   - definition: The expected field definitions
    /// - Returns: A tuple with validation result and error details
    private func validateRecordFields(
        _ fields: [String: RuntimeValue],
        definition: [RecordField]
    ) -> (isValid: Bool, errorDetail: String?) {
        let definedFieldNames = Set(definition.map { $0.name })

        // Check for extra fields not in definition
        for fieldName in fields.keys where !definedFieldNames.contains(fieldName) {
            return (false, "unexpected field '\(fieldName)'")
        }

        // Check all defined fields exist and have correct types
        for field in definition {
            guard let value = fields[field.name] else {
                return (false, "missing field '\(field.name)'")
            }
            if case .undefined = value {
                // Undefined is compatible with any type
                continue
            }
            if let actualType = inferDataType(from: value) {
                if !typesMatch(actualType, expected: field.type) {
                    return (false, "field '\(field.name)' has type \(actualType), expected \(field.type)")
                }
            } else {
                return (false, "cannot infer type of field '\(field.name)'")
            }
        }
        return (true, nil)
    }
}
