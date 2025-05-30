import Foundation

/// Configuration for semantic analysis behavior.
public struct SemanticAnalysisConfig: Sendable {
    /// Maximum depth for type inference to prevent infinite recursion.
    public let maxInferenceDepth: Int

    /// Maximum nesting depth for expressions and statements.
    public let maxNestingDepth: Int

    /// Error reporting configuration.
    public let errorReporting: SemanticErrorReportingConfig

    /// Whether to enable strict type checking.
    public let strictTypeChecking: Bool

    /// Whether to enable unused symbol warnings.
    public let enableUnusedWarnings: Bool

    public init(
        maxInferenceDepth: Int = 50,
        maxNestingDepth: Int = 100,
        errorReporting: SemanticErrorReportingConfig = .default,
        strictTypeChecking: Bool = true,
        enableUnusedWarnings: Bool = true
    ) {
        self.maxInferenceDepth = maxInferenceDepth
        self.maxNestingDepth = maxNestingDepth
        self.errorReporting = errorReporting
        self.strictTypeChecking = strictTypeChecking
        self.enableUnusedWarnings = enableUnusedWarnings
    }

    /// Default configuration.
    public static let `default` = SemanticAnalysisConfig()

    /// Strict configuration with all checks enabled.
    public static let strict = SemanticAnalysisConfig(
        maxInferenceDepth: 100,
        maxNestingDepth: 200,
        errorReporting: .strict,
        strictTypeChecking: true,
        enableUnusedWarnings: true
    )

    /// Fast configuration optimized for performance.
    public static let fast = SemanticAnalysisConfig(
        maxInferenceDepth: 25,
        maxNestingDepth: 50,
        errorReporting: .fast,
        strictTypeChecking: false,
        enableUnusedWarnings: false
    )
}

/// Multi-pass semantic analyzer for FE pseudo-language.
public final class SemanticAnalyzer: @unchecked Sendable {

    // MARK: - Properties

    private let config: SemanticAnalysisConfig
    private var symbolTable: SymbolTable
    private var errorReporter: SemanticErrorReporter
    private var currentNestingDepth: Int = 0

    // MARK: - Initialization

    public init(config: SemanticAnalysisConfig = .default) {
        self.config = config
        self.symbolTable = SymbolTable()
        self.errorReporter = SemanticErrorReporter(config: config.errorReporting)
    }

    // MARK: - Public Interface

    /// Analyze a list of statements with multi-pass semantic analysis.
    public func analyze(_ statements: [Statement]) -> SemanticAnalysisResult {
        // Reset state for new analysis
        reset()

        // Pass 1: Symbol Collection
        collectSymbols(statements)

        // Pass 2: Type Checking
        if !errorReporter.hasReachedErrorLimit {
            performTypeChecking(statements)
        }

        // Pass 3: Semantic Validation
        if !errorReporter.hasReachedErrorLimit {
            performSemanticValidation(statements)
        }

        return errorReporter.finalize(with: symbolTable)
    }

    /// Reset the analyzer for reuse.
    public func reset() {
        symbolTable.reset()
        errorReporter.reset()
        currentNestingDepth = 0
    }

    // MARK: - Pass 1: Symbol Collection

    private func collectSymbols(_ statements: [Statement]) {
        for statement in statements {
            collectSymbolsFromStatement(statement)
            if errorReporter.hasReachedErrorLimit {
                break
            }
        }
    }

    private func collectSymbolsFromStatement(_ statement: Statement) {
        incrementNestingDepth()
        defer { decrementNestingDepth() }

        switch statement {
        case .variableDeclaration(let decl):
            collectSymbolsFromVariableDeclaration(decl)
        case .constantDeclaration(let decl):
            collectSymbolsFromConstantDeclaration(decl)
        case .functionDeclaration(let decl):
            collectSymbolsFromFunctionDeclaration(decl)
        case .procedureDeclaration(let decl):
            collectSymbolsFromProcedureDeclaration(decl)
        case .ifStatement(let stmt):
            collectSymbolsFromIfStatement(stmt)
        case .whileStatement(let stmt):
            collectSymbolsFromWhileStatement(stmt)
        case .forStatement(let stmt):
            collectSymbolsFromForStatement(stmt)
        case .block(let statements):
            _ = symbolTable.pushScope(kind: .block)
            for stmt in statements {
                collectSymbolsFromStatement(stmt)
            }
            symbolTable.popScope()
        case .assignment, .expressionStatement, .returnStatement, .breakStatement:
            // These don't declare new symbols
            break
        }
    }

    private func collectSymbolsFromVariableDeclaration(_ decl: VariableDeclaration) {
        let feType = convertDataTypeToFeType(decl.type)
        let position = SourcePosition(line: 0, column: 0, offset: 0) // TODO: Add real position tracking
        let isInitialized = decl.initialValue != nil

        let result = symbolTable.declare(
            name: decl.name,
            type: feType,
            kind: .variable,
            position: position,
            isInitialized: isInitialized
        )

        if case .failure(let error) = result {
            errorReporter.collect(error)
        }
    }

    private func collectSymbolsFromConstantDeclaration(_ decl: ConstantDeclaration) {
        let feType = convertDataTypeToFeType(decl.type)
        let position = SourcePosition(line: 0, column: 0, offset: 0) // TODO: Add real position tracking

        let result = symbolTable.declare(
            name: decl.name,
            type: feType,
            kind: .constant,
            position: position,
            isInitialized: true
        )

        if case .failure(let error) = result {
            errorReporter.collect(error)
        }
    }

    private func collectSymbolsFromFunctionDeclaration(_ decl: FunctionDeclaration) {
        let position = SourcePosition(line: 0, column: 0, offset: 0)
        let returnType = decl.returnType.map(convertDataTypeToFeType)
        let paramTypes = decl.parameters.map { convertDataTypeToFeType($0.type) }
        let functionType = FeType.function(parameters: paramTypes, returnType: returnType)

        // Check if function is already declared in current scope
        if symbolTable.existsInCurrentScope(decl.name) {
            errorReporter.collect(.functionAlreadyDeclared(decl.name, position: position))
            return
        }

        // Declare function in current scope
        let result = symbolTable.declare(
            name: decl.name,
            type: functionType,
            kind: .function,
            position: position,
            isInitialized: true
        )

        if case .failure(let error) = result {
            errorReporter.collect(error)
            return
        }

        // Create function scope and collect parameters and local variables
        _ = symbolTable.pushScope(kind: .function(name: decl.name, returnType: returnType))

        // Declare parameters
        for param in decl.parameters {
            let paramType = convertDataTypeToFeType(param.type)
            let paramResult = symbolTable.declare(
                name: param.name,
                type: paramType,
                kind: .parameter,
                position: position,
                isInitialized: true
            )

            if case .failure(let error) = paramResult {
                errorReporter.collect(error)
            }
        }

        // Declare local variables
        for localVar in decl.localVariables {
            collectSymbolsFromVariableDeclaration(localVar)
        }

        // Collect symbols from body
        for stmt in decl.body {
            collectSymbolsFromStatement(stmt)
        }

        symbolTable.popScope()
    }

    private func collectSymbolsFromProcedureDeclaration(_ decl: ProcedureDeclaration) {
        let position = SourcePosition(line: 0, column: 0, offset: 0)
        let paramTypes = decl.parameters.map { convertDataTypeToFeType($0.type) }
        let procedureType = FeType.function(parameters: paramTypes, returnType: nil)

        // Declare procedure in current scope
        let result = symbolTable.declare(
            name: decl.name,
            type: procedureType,
            kind: .procedure,
            position: position,
            isInitialized: true
        )

        if case .failure(let error) = result {
            errorReporter.collect(error)
            return
        }

        // Create procedure scope and collect parameters and local variables
        _ = symbolTable.pushScope(kind: .procedure(name: decl.name))

        // Declare parameters
        for param in decl.parameters {
            let paramType = convertDataTypeToFeType(param.type)
            let paramResult = symbolTable.declare(
                name: param.name,
                type: paramType,
                kind: .parameter,
                position: position,
                isInitialized: true
            )

            if case .failure(let error) = paramResult {
                errorReporter.collect(error)
            }
        }

        // Declare local variables
        for localVar in decl.localVariables {
            collectSymbolsFromVariableDeclaration(localVar)
        }

        // Collect symbols from body
        for stmt in decl.body {
            collectSymbolsFromStatement(stmt)
        }

        symbolTable.popScope()
    }

    private func collectSymbolsFromIfStatement(_ stmt: IfStatement) {
        // Push block scope for then body
        _ = symbolTable.pushScope(kind: .block)
        for thenStmt in stmt.thenBody {
            collectSymbolsFromStatement(thenStmt)
        }
        symbolTable.popScope()

        // Push block scope for each elseif body
        for elseIf in stmt.elseIfs {
            _ = symbolTable.pushScope(kind: .block)
            for elseIfStmt in elseIf.body {
                collectSymbolsFromStatement(elseIfStmt)
            }
            symbolTable.popScope()
        }

        // Push block scope for else body if present
        if let elseBody = stmt.elseBody {
            _ = symbolTable.pushScope(kind: .block)
            for elseStmt in elseBody {
                collectSymbolsFromStatement(elseStmt)
            }
            symbolTable.popScope()
        }
    }

    private func collectSymbolsFromWhileStatement(_ stmt: WhileStatement) {
        _ = symbolTable.pushScope(kind: .loop)
        for bodyStmt in stmt.body {
            collectSymbolsFromStatement(bodyStmt)
        }
        symbolTable.popScope()
    }

    private func collectSymbolsFromForStatement(_ stmt: ForStatement) {
        switch stmt {
        case .range(let rangeFor):
            _ = symbolTable.pushScope(kind: .loop)

            // Declare loop variable
            let position = SourcePosition(line: 0, column: 0, offset: 0)
            let result = symbolTable.declare(
                name: rangeFor.variable,
                type: .integer,
                kind: .variable,
                position: position,
                isInitialized: true
            )

            if case .failure(let error) = result {
                errorReporter.collect(error)
            }

            for bodyStmt in rangeFor.body {
                collectSymbolsFromStatement(bodyStmt)
            }
            symbolTable.popScope()

        case .forEach(let forEach):
            _ = symbolTable.pushScope(kind: .loop)

            // Declare loop variable (type will be inferred in type checking pass)
            let position = SourcePosition(line: 0, column: 0, offset: 0)
            let result = symbolTable.declare(
                name: forEach.variable,
                type: .unknown, // Will be resolved in type checking
                kind: .variable,
                position: position,
                isInitialized: true
            )

            if case .failure(let error) = result {
                errorReporter.collect(error)
            }

            for bodyStmt in forEach.body {
                collectSymbolsFromStatement(bodyStmt)
            }
            symbolTable.popScope()
        }
    }

    // MARK: - Pass 2: Type Checking

    private func performTypeChecking(_ statements: [Statement]) {
        for statement in statements {
            typeCheckStatement(statement)
            if errorReporter.hasReachedErrorLimit {
                break
            }
        }
    }

    private func typeCheckStatement(_ statement: Statement) {
        incrementNestingDepth()
        defer { decrementNestingDepth() }

        switch statement {
        case .variableDeclaration(let decl):
            typeCheckVariableDeclaration(decl)
        case .constantDeclaration(let decl):
            typeCheckConstantDeclaration(decl)
        case .assignment(let assignment):
            typeCheckAssignment(assignment)
        case .ifStatement(let stmt):
            typeCheckIfStatement(stmt)
        case .whileStatement(let stmt):
            typeCheckWhileStatement(stmt)
        case .forStatement(let stmt):
            typeCheckForStatement(stmt)
        case .returnStatement(let stmt):
            typeCheckReturnStatement(stmt)
        case .expressionStatement(let expr):
            _ = inferExpressionType(expr)
        case .functionDeclaration(let decl):
            typeCheckFunctionDeclaration(decl)
        case .procedureDeclaration(let decl):
            typeCheckProcedureDeclaration(decl)
        case .block(let statements):
            _ = symbolTable.pushScope(kind: .block)
            for stmt in statements {
                typeCheckStatement(stmt)
            }
            symbolTable.popScope()
        case .breakStatement:
            // No type checking needed
            break
        }
    }

    private func typeCheckVariableDeclaration(_ decl: VariableDeclaration) {
        guard let initialValue = decl.initialValue else {
            return // No initial value to check
        }

        let expectedType = convertDataTypeToFeType(decl.type)
        let actualType = inferExpressionType(initialValue)

        if !actualType.canAssignTo(expectedType) {
            let position = SourcePosition(line: 0, column: 0, offset: 0)
            errorReporter.collect(.typeMismatch(expected: expectedType, actual: actualType, position: position))
        }
    }

    private func typeCheckConstantDeclaration(_ decl: ConstantDeclaration) {
        let expectedType = convertDataTypeToFeType(decl.type)
        let actualType = inferExpressionType(decl.initialValue)

        if !actualType.canAssignTo(expectedType) {
            let position = SourcePosition(line: 0, column: 0, offset: 0)
            errorReporter.collect(.typeMismatch(expected: expectedType, actual: actualType, position: position))
        }
    }

    private func typeCheckAssignment(_ assignment: Assignment) {
        switch assignment {
        case .variable(let name, let expr):
            guard let symbol = symbolTable.lookup(name) else {
                let position = SourcePosition(line: 0, column: 0, offset: 0)
                errorReporter.collect(.undeclaredVariable(name, position: position))
                return
            }

            if symbol.kind == .constant {
                let position = SourcePosition(line: 0, column: 0, offset: 0)
                errorReporter.collect(.constantReassignment(name, position: position))
                return
            }

            let actualType = inferExpressionType(expr)
            if !actualType.canAssignTo(symbol.type) {
                let position = SourcePosition(line: 0, column: 0, offset: 0)
                errorReporter.collect(.typeMismatch(expected: symbol.type, actual: actualType, position: position))
            }

            // Mark as initialized and used
            let position = SourcePosition(line: 0, column: 0, offset: 0)
            _ = symbolTable.markAsInitialized(name, position: position)
            _ = symbolTable.markAsUsed(name, position: position)

        case .arrayElement(let arrayAccess, let expr):
            let arrayType = inferExpressionType(arrayAccess.array)
            let indexType = inferExpressionType(arrayAccess.index)
            let valueType = inferExpressionType(expr)

            // Check that we're accessing an array
            guard case .array(let elementType, _) = arrayType else {
                let position = SourcePosition(line: 0, column: 0, offset: 0)
                errorReporter.collect(.invalidArrayAccess(position: position))
                return
            }

            // Check index type
            if !indexType.isCompatible(with: .integer) {
                let position = SourcePosition(line: 0, column: 0, offset: 0)
                errorReporter.collect(.arrayIndexTypeMismatch(expected: .integer, actual: indexType, position: position))
            }

            // Check value type
            if !valueType.canAssignTo(elementType) {
                let position = SourcePosition(line: 0, column: 0, offset: 0)
                errorReporter.collect(.typeMismatch(expected: elementType, actual: valueType, position: position))
            }
        }
    }

    private func typeCheckIfStatement(_ stmt: IfStatement) {
        let conditionType = inferExpressionType(stmt.condition)
        if !conditionType.isCompatible(with: .boolean) {
            let position = SourcePosition(line: 0, column: 0, offset: 0)
            errorReporter.collect(.typeMismatch(expected: .boolean, actual: conditionType, position: position))
        }

        _ = symbolTable.pushScope(kind: .block)
        for thenStmt in stmt.thenBody {
            typeCheckStatement(thenStmt)
        }
        symbolTable.popScope()

        for elseIf in stmt.elseIfs {
            let elseIfConditionType = inferExpressionType(elseIf.condition)
            if !elseIfConditionType.isCompatible(with: .boolean) {
                let position = SourcePosition(line: 0, column: 0, offset: 0)
                errorReporter.collect(.typeMismatch(expected: .boolean, actual: elseIfConditionType, position: position))
            }

            _ = symbolTable.pushScope(kind: .block)
            for elseIfStmt in elseIf.body {
                typeCheckStatement(elseIfStmt)
            }
            symbolTable.popScope()
        }

        if let elseBody = stmt.elseBody {
            _ = symbolTable.pushScope(kind: .block)
            for elseStmt in elseBody {
                typeCheckStatement(elseStmt)
            }
            symbolTable.popScope()
        }
    }

    private func typeCheckWhileStatement(_ stmt: WhileStatement) {
        let conditionType = inferExpressionType(stmt.condition)
        if !conditionType.isCompatible(with: .boolean) {
            let position = SourcePosition(line: 0, column: 0, offset: 0)
            errorReporter.collect(.typeMismatch(expected: .boolean, actual: conditionType, position: position))
        }

        _ = symbolTable.pushScope(kind: .loop)
        for bodyStmt in stmt.body {
            typeCheckStatement(bodyStmt)
        }
        symbolTable.popScope()
    }

    private func typeCheckForStatement(_ stmt: ForStatement) {
        switch stmt {
        case .range(let rangeFor):
            let startType = inferExpressionType(rangeFor.start)
            let endType = inferExpressionType(rangeFor.end)

            if startType != .integer && startType != .unknown && startType != .error {
                let position = SourcePosition(line: 0, column: 0, offset: 0)
                errorReporter.collect(.typeMismatch(expected: .integer, actual: startType, position: position))
            }

            if endType != .integer && endType != .unknown && endType != .error {
                let position = SourcePosition(line: 0, column: 0, offset: 0)
                errorReporter.collect(.typeMismatch(expected: .integer, actual: endType, position: position))
            }

            if let step = rangeFor.step {
                let stepType = inferExpressionType(step)
                if stepType != .integer && stepType != .unknown && stepType != .error {
                    let position = SourcePosition(line: 0, column: 0, offset: 0)
                    errorReporter.collect(.typeMismatch(expected: .integer, actual: stepType, position: position))
                }
            }

            _ = symbolTable.pushScope(kind: .loop)

            // Re-declare loop variable in type checking scope
            let position = SourcePosition(line: 0, column: 0, offset: 0)
            _ = symbolTable.declare(
                name: rangeFor.variable,
                type: .integer,
                kind: .variable,
                position: position,
                isInitialized: true
            )

            for bodyStmt in rangeFor.body {
                typeCheckStatement(bodyStmt)
            }
            symbolTable.popScope()

        case .forEach(let forEach):
            let iterableType = inferExpressionType(forEach.iterable)

            // Extract element type from iterable
            let elementType: FeType
            switch iterableType {
            case .array(let elemType, _):
                elementType = elemType
            case .string:
                elementType = .character
            default:
                let position = SourcePosition(line: 0, column: 0, offset: 0)
                errorReporter.collect(.typeMismatch(expected: .array(elementType: .unknown, dimensions: []), actual: iterableType, position: position))
                elementType = .error
            }

            _ = symbolTable.pushScope(kind: .loop)

            // Re-declare loop variable with correct type in type checking scope
            let position = SourcePosition(line: 0, column: 0, offset: 0)
            _ = symbolTable.declare(
                name: forEach.variable,
                type: elementType,
                kind: .variable,
                position: position,
                isInitialized: true
            )

            for bodyStmt in forEach.body {
                typeCheckStatement(bodyStmt)
            }
            symbolTable.popScope()
        }
    }

    private func typeCheckReturnStatement(_ stmt: ReturnStatement) {
        guard let currentFunction = symbolTable.currentFunction else {
            let position = SourcePosition(line: 0, column: 0, offset: 0)
            errorReporter.collect(.returnOutsideFunction(position: position))
            return
        }

        let expectedReturnType = currentFunction.returnType

        if let returnExpr = stmt.expression {
            let actualReturnType = inferExpressionType(returnExpr)

            if let expected = expectedReturnType {
                if !actualReturnType.canAssignTo(expected) {
                    let position = SourcePosition(line: 0, column: 0, offset: 0)
                    errorReporter.collect(.returnTypeMismatch(function: currentFunction.name, expected: expected, actual: actualReturnType, position: position))
                }
            } else {
                // Procedure returning a value
                let position = SourcePosition(line: 0, column: 0, offset: 0)
                errorReporter.collect(.voidFunctionReturnsValue(function: currentFunction.name, position: position))
            }
        } else {
            // No return expression
            if expectedReturnType != nil {
                // Function not returning a value
                let position = SourcePosition(line: 0, column: 0, offset: 0)
                errorReporter.collect(.missingReturnStatement(function: currentFunction.name, position: position))
            }
        }
    }

    private func typeCheckFunctionDeclaration(_ decl: FunctionDeclaration) {
        let returnType = decl.returnType.map(convertDataTypeToFeType)
        _ = symbolTable.pushScope(kind: .function(name: decl.name, returnType: returnType))

        // Re-declare parameters in the new scope
        let position = SourcePosition(line: 0, column: 0, offset: 0)
        for param in decl.parameters {
            let paramType = convertDataTypeToFeType(param.type)
            let paramResult = symbolTable.declare(
                name: param.name,
                type: paramType,
                kind: .parameter,
                position: position,
                isInitialized: true
            )

            if case .failure(let error) = paramResult {
                errorReporter.collect(error)
            }
        }

        // Re-declare local variables in the new scope
        for localVar in decl.localVariables {
            collectSymbolsFromVariableDeclaration(localVar)
        }

        // Type check local variables
        for localVar in decl.localVariables {
            typeCheckVariableDeclaration(localVar)
        }

        // Type check body
        for stmt in decl.body {
            typeCheckStatement(stmt)
        }

        symbolTable.popScope()
    }

    private func typeCheckProcedureDeclaration(_ decl: ProcedureDeclaration) {
        _ = symbolTable.pushScope(kind: .procedure(name: decl.name))

        // Re-declare parameters in the new scope
        let position = SourcePosition(line: 0, column: 0, offset: 0)
        for param in decl.parameters {
            let paramType = convertDataTypeToFeType(param.type)
            let paramResult = symbolTable.declare(
                name: param.name,
                type: paramType,
                kind: .parameter,
                position: position,
                isInitialized: true
            )

            if case .failure(let error) = paramResult {
                errorReporter.collect(error)
            }
        }

        // Re-declare local variables in the new scope
        for localVar in decl.localVariables {
            collectSymbolsFromVariableDeclaration(localVar)
        }

        // Type check local variables
        for localVar in decl.localVariables {
            typeCheckVariableDeclaration(localVar)
        }

        // Type check body
        for stmt in decl.body {
            typeCheckStatement(stmt)
        }

        symbolTable.popScope()
    }

    // MARK: - Type Inference

    private func inferExpressionType(_ expression: Expression, depth: Int = 0) -> FeType {
        guard depth < config.maxInferenceDepth else {
            let position = SourcePosition(line: 0, column: 0, offset: 0)
            errorReporter.collect(.analysisDepthExceeded(position: position))
            return .error
        }

        switch expression {
        case .literal(let literal):
            return inferLiteralType(literal)
        case .identifier(let name):
            return inferIdentifierType(name)
        case .binary(let operatorType, let left, let right):
            return inferBinaryOperationType(operatorType, left: left, right: right, depth: depth + 1)
        case .unary(let operatorType, let operand):
            return inferUnaryOperationType(operatorType, operand: operand, depth: depth + 1)
        case .arrayAccess(let array, let index):
            return inferArrayAccessType(array, index: index, depth: depth + 1)
        case .fieldAccess(let object, let field):
            return inferFieldAccessType(object, field: field, depth: depth + 1)
        case .functionCall(let name, let arguments):
            return inferFunctionCallType(name, arguments: arguments, depth: depth + 1)
        }
    }

    private func inferLiteralType(_ literal: Literal) -> FeType {
        switch literal {
        case .integer:
            return .integer
        case .real:
            return .real
        case .string:
            return .string
        case .character:
            return .character
        case .boolean:
            return .boolean
        }
    }

    private func inferIdentifierType(_ name: String) -> FeType {
        guard let symbol = symbolTable.lookup(name) else {
            let position = SourcePosition(line: 0, column: 0, offset: 0)
            errorReporter.collect(.undeclaredVariable(name, position: position))
            return .error
        }

        // Mark as used
        let position = SourcePosition(line: 0, column: 0, offset: 0)
        _ = symbolTable.markAsUsed(name, position: position)

        return symbol.type
    }

    private func inferBinaryOperationType(_ operatorType: BinaryOperator, left: Expression, right: Expression, depth: Int) -> FeType {
        let leftType = inferExpressionType(left, depth: depth)
        let rightType = inferExpressionType(right, depth: depth)

        switch operatorType {
        case .add, .subtract, .multiply, .divide:
            // Arithmetic operators
            if leftType.isCompatible(with: .integer) && rightType.isCompatible(with: .integer) {
                return .integer
            } else if (leftType.isCompatible(with: .real) || leftType.isCompatible(with: .integer)) &&
                      (rightType.isCompatible(with: .real) || rightType.isCompatible(with: .integer)) {
                return .real
            } else if operatorType == .add && (leftType.isCompatible(with: .string) || rightType.isCompatible(with: .string)) {
                // String concatenation with + operator
                if (leftType.isCompatible(with: .string) || leftType.isCompatible(with: .character)) &&
                   (rightType.isCompatible(with: .string) || rightType.isCompatible(with: .character)) {
                    return .string
                } else {
                    let position = SourcePosition(line: 0, column: 0, offset: 0)
                    errorReporter.collect(.incompatibleTypes(leftType, rightType, operation: operatorType.operationName, position: position))
                    return .error
                }
            } else {
                let position = SourcePosition(line: 0, column: 0, offset: 0)
                errorReporter.collect(.incompatibleTypes(leftType, rightType, operation: operatorType.operationName, position: position))
                return .error
            }

        case .modulo:
            // Modulo only works with integers (exact type match required)
            if leftType == .integer && rightType == .integer {
                return .integer
            } else {
                let position = SourcePosition(line: 0, column: 0, offset: 0)
                errorReporter.collect(.incompatibleTypes(leftType, rightType, operation: operatorType.operationName, position: position))
                return .error
            }

        case .equal, .notEqual:
            // Equality operators work with compatible types
            if leftType.isCompatible(with: rightType) {
                return .boolean
            } else {
                let position = SourcePosition(line: 0, column: 0, offset: 0)
                errorReporter.collect(.incompatibleTypes(leftType, rightType, operation: operatorType.operationName, position: position))
                return .error
            }

        case .greater, .greaterEqual, .less, .lessEqual:
            // Comparison operators work with numeric types
            if (leftType.isCompatible(with: .integer) || leftType.isCompatible(with: .real)) &&
               (rightType.isCompatible(with: .integer) || rightType.isCompatible(with: .real)) {
                return .boolean
            } else {
                let position = SourcePosition(line: 0, column: 0, offset: 0)
                errorReporter.collect(.incompatibleTypes(leftType, rightType, operation: operatorType.operationName, position: position))
                return .error
            }

        case .and, .or:
            // Logical operators work with boolean types
            if leftType.isCompatible(with: .boolean) && rightType.isCompatible(with: .boolean) {
                return .boolean
            } else {
                let position = SourcePosition(line: 0, column: 0, offset: 0)
                errorReporter.collect(.incompatibleTypes(leftType, rightType, operation: operatorType.operationName, position: position))
                return .error
            }
        }
    }

    private func inferUnaryOperationType(_ operatorType: UnaryOperator, operand: Expression, depth: Int) -> FeType {
        let operandType = inferExpressionType(operand, depth: depth)

        switch operatorType {
        case .not:
            if operandType.isCompatible(with: .boolean) {
                return .boolean
            } else {
                let position = SourcePosition(line: 0, column: 0, offset: 0)
                errorReporter.collect(.typeMismatch(expected: .boolean, actual: operandType, position: position))
                return .error
            }

        case .plus, .minus:
            if operandType.isCompatible(with: .integer) {
                return .integer
            } else if operandType.isCompatible(with: .real) {
                return .real
            } else {
                let position = SourcePosition(line: 0, column: 0, offset: 0)
                errorReporter.collect(.typeMismatch(expected: .real, actual: operandType, position: position))
                return .error
            }
        }
    }

    private func inferArrayAccessType(_ array: Expression, index: Expression, depth: Int) -> FeType {
        let arrayType = inferExpressionType(array, depth: depth)
        let indexType = inferExpressionType(index, depth: depth)

        // Check index type
        if !indexType.isCompatible(with: .integer) {
            let position = SourcePosition(line: 0, column: 0, offset: 0)
            errorReporter.collect(.arrayIndexTypeMismatch(expected: .integer, actual: indexType, position: position))
        }

        // Extract element type
        switch arrayType {
        case .array(let elementType, _):
            return elementType
        case .string:
            return .character
        default:
            let position = SourcePosition(line: 0, column: 0, offset: 0)
            errorReporter.collect(.invalidArrayAccess(position: position))
            return .error
        }
    }

    private func inferFieldAccessType(_ object: Expression, field: String, depth: Int) -> FeType {
        let objectType = inferExpressionType(object, depth: depth)

        switch objectType {
        case .record(let name, let fields):
            if let fieldType = fields[field] {
                return fieldType
            } else {
                let position = SourcePosition(line: 0, column: 0, offset: 0)
                errorReporter.collect(.undeclaredField(fieldName: field, recordType: name, position: position))
                return .error
            }
        default:
            let position = SourcePosition(line: 0, column: 0, offset: 0)
            errorReporter.collect(.invalidFieldAccess(position: position))
            return .error
        }
    }

    private func inferFunctionCallType(_ name: String, arguments: [Expression], depth: Int) -> FeType {
        guard let symbol = symbolTable.lookup(name) else {
            let position = SourcePosition(line: 0, column: 0, offset: 0)
            errorReporter.collect(.undeclaredFunction(name, position: position))
            return .error
        }

        guard case .function(let paramTypes, let returnType) = symbol.type else {
            let position = SourcePosition(line: 0, column: 0, offset: 0)
            errorReporter.collect(.undeclaredFunction(name, position: position))
            return .error
        }

        // Check argument count
        if arguments.count != paramTypes.count {
            let position = SourcePosition(line: 0, column: 0, offset: 0)
            errorReporter.collect(.incorrectArgumentCount(function: name, expected: paramTypes.count, actual: arguments.count, position: position))
            return returnType ?? .void
        }

        // Check argument types
        for (index, (argument, expectedType)) in zip(arguments, paramTypes).enumerated() {
            let actualType = inferExpressionType(argument, depth: depth)
            if !actualType.canAssignTo(expectedType) {
                let position = SourcePosition(line: 0, column: 0, offset: 0)
                errorReporter.collect(.argumentTypeMismatch(function: name, paramIndex: index, expected: expectedType, actual: actualType, position: position))
            }
        }

        // Mark function as used
        let position = SourcePosition(line: 0, column: 0, offset: 0)
        _ = symbolTable.markAsUsed(name, position: position)

        return returnType ?? .void
    }

    // MARK: - Pass 3: Semantic Validation

    private func performSemanticValidation(_ statements: [Statement]) {
        for statement in statements {
            validateStatement(statement)
            if errorReporter.hasReachedErrorLimit {
                break
            }
        }

        // Post-validation checks for unused variables and functions
        if config.enableUnusedWarnings {
            validateUnusedSymbols()
        }
    }

    private func validateUnusedSymbols() {
        // This will be handled by the error reporter during finalization
        // The symbol table already tracks usage, so unused symbols will be
        // converted to warnings in the error reporter's finalize method
    }

    private func validateStatement(_ statement: Statement) {
        incrementNestingDepth()
        defer { decrementNestingDepth() }

        switch statement {
        case .breakStatement:
            validateBreakStatement()
        case .returnStatement(let stmt):
            validateReturnStatement(stmt)
        case .ifStatement(let stmt):
            validateIfStatement(stmt)
        case .whileStatement(let stmt):
            validateWhileStatement(stmt)
        case .forStatement(let stmt):
            validateForStatement(stmt)
        case .functionDeclaration(let decl):
            validateFunctionDeclaration(decl)
        case .procedureDeclaration(let decl):
            validateProcedureDeclaration(decl)
        case .block(let statements):
            _ = symbolTable.pushScope(kind: .block)
            for stmt in statements {
                validateStatement(stmt)
            }
            symbolTable.popScope()
        case .variableDeclaration, .constantDeclaration, .assignment, .expressionStatement:
            // These are validated in type checking pass
            break
        }
    }

    private func validateBreakStatement() {
        if !symbolTable.isInLoop {
            let position = SourcePosition(line: 0, column: 0, offset: 0)
            errorReporter.collect(.breakOutsideLoop(position: position))
        }
    }

    private func validateReturnStatement(_ stmt: ReturnStatement) {
        if !symbolTable.isInFunction {
            let position = SourcePosition(line: 0, column: 0, offset: 0)
            errorReporter.collect(.returnOutsideFunction(position: position))
        }
    }

    private func validateIfStatement(_ stmt: IfStatement) {
        _ = symbolTable.pushScope(kind: .block)
        for thenStmt in stmt.thenBody {
            validateStatement(thenStmt)
        }
        symbolTable.popScope()

        for elseIf in stmt.elseIfs {
            _ = symbolTable.pushScope(kind: .block)
            for elseIfStmt in elseIf.body {
                validateStatement(elseIfStmt)
            }
            symbolTable.popScope()
        }

        if let elseBody = stmt.elseBody {
            _ = symbolTable.pushScope(kind: .block)
            for elseStmt in elseBody {
                validateStatement(elseStmt)
            }
            symbolTable.popScope()
        }
    }

    private func validateWhileStatement(_ stmt: WhileStatement) {
        _ = symbolTable.pushScope(kind: .loop)
        for bodyStmt in stmt.body {
            validateStatement(bodyStmt)
        }
        symbolTable.popScope()
    }

    private func validateForStatement(_ stmt: ForStatement) {
        switch stmt {
        case .range(let rangeFor):
            _ = symbolTable.pushScope(kind: .loop)
            for bodyStmt in rangeFor.body {
                validateStatement(bodyStmt)
            }
            symbolTable.popScope()
        case .forEach(let forEach):
            _ = symbolTable.pushScope(kind: .loop)
            for bodyStmt in forEach.body {
                validateStatement(bodyStmt)
            }
            symbolTable.popScope()
        }
    }

    private func validateFunctionDeclaration(_ decl: FunctionDeclaration) {
        let returnType = decl.returnType.map(convertDataTypeToFeType)
        _ = symbolTable.pushScope(kind: .function(name: decl.name, returnType: returnType))

        // Re-declare parameters in the new scope
        let position = SourcePosition(line: 0, column: 0, offset: 0)
        for param in decl.parameters {
            let paramType = convertDataTypeToFeType(param.type)
            _ = symbolTable.declare(
                name: param.name,
                type: paramType,
                kind: .parameter,
                position: position,
                isInitialized: true
            )
        }

        // Re-declare local variables in the new scope
        for localVar in decl.localVariables {
            collectSymbolsFromVariableDeclaration(localVar)
        }

        // Validate function body and check for return statements
        for stmt in decl.body {
            validateStatement(stmt)
        }

        // Check for missing return statement in functions (not procedures)
        if decl.returnType != nil && !containsReturnStatement(decl.body) {
            errorReporter.collect(.missingReturnStatement(function: decl.name, position: position))
        }

        // Validate parameter uniqueness
        let paramNames = decl.parameters.map { $0.name }
        let uniqueParamNames = Set(paramNames)
        if paramNames.count != uniqueParamNames.count {
            // Find duplicate parameter
            var seen: Set<String> = []
            for paramName in paramNames {
                if seen.contains(paramName) {
                    errorReporter.collect(.variableAlreadyDeclared(paramName, position: position))
                    break
                }
                seen.insert(paramName)
            }
        }

        symbolTable.popScope()
    }

    private func validateProcedureDeclaration(_ decl: ProcedureDeclaration) {
        _ = symbolTable.pushScope(kind: .procedure(name: decl.name))

        // Re-declare parameters in the new scope
        let position = SourcePosition(line: 0, column: 0, offset: 0)
        for param in decl.parameters {
            let paramType = convertDataTypeToFeType(param.type)
            _ = symbolTable.declare(
                name: param.name,
                type: paramType,
                kind: .parameter,
                position: position,
                isInitialized: true
            )
        }

        // Re-declare local variables in the new scope
        for localVar in decl.localVariables {
            collectSymbolsFromVariableDeclaration(localVar)
        }

        // Validate procedure body
        var hasUnreachableCode = false
        for (index, stmt) in decl.body.enumerated() {
            if hasUnreachableCode {
                // Code after return statement is unreachable
                errorReporter.collect(SemanticError.unreachableCode(position: position))
                break
            }

            validateStatement(stmt)

            if case .returnStatement = stmt {
                // Mark that subsequent statements are unreachable
                if index < decl.body.count - 1 {
                    hasUnreachableCode = true
                }
            }
        }

        // Validate parameter uniqueness
        let paramNames = decl.parameters.map { $0.name }
        let uniqueParamNames = Set(paramNames)
        if paramNames.count != uniqueParamNames.count {
            // Find duplicate parameter
            var seen: Set<String> = []
            for paramName in paramNames {
                if seen.contains(paramName) {
                    errorReporter.collect(.variableAlreadyDeclared(paramName, position: position))
                    break
                }
                seen.insert(paramName)
            }
        }

        symbolTable.popScope()
    }

    // MARK: - Helper Methods

    private func convertDataTypeToFeType(_ dataType: DataType) -> FeType {
        switch dataType {
        case .integer:
            return .integer
        case .real:
            return .real
        case .character:
            return .character
        case .string:
            return .string
        case .boolean:
            return .boolean
        case .array(let elementType):
            let feElementType = convertDataTypeToFeType(elementType)
            return .array(elementType: feElementType, dimensions: [])
        case .record(let name):
            return .record(name: name, fields: [:])
        }
    }

    private func incrementNestingDepth() {
        currentNestingDepth += 1
        if currentNestingDepth > config.maxNestingDepth {
            let position = SourcePosition(line: 0, column: 0, offset: 0)
            errorReporter.collect(.analysisDepthExceeded(position: position))
        }
    }

    private func decrementNestingDepth() {
        currentNestingDepth = max(0, currentNestingDepth - 1)
    }

    /// Recursively check if a list of statements contains a return statement.
    private func containsReturnStatement(_ statements: [Statement]) -> Bool {
        for stmt in statements {
            if containsReturnStatement(stmt) {
                return true
            }
        }
        return false
    }

    /// Recursively check if a statement contains a return statement.
    private func containsReturnStatement(_ statement: Statement) -> Bool {
        switch statement {
        case .returnStatement:
            return true
        case .block(let statements):
            return containsReturnStatement(statements)
        case .ifStatement(let ifStmt):
            if containsReturnStatement(ifStmt.thenBody) {
                return true
            }
            for elseIf in ifStmt.elseIfs {
                if containsReturnStatement(elseIf.body) {
                    return true
                }
            }
            if let elseBody = ifStmt.elseBody {
                return containsReturnStatement(elseBody)
            }
            return false
        case .whileStatement(let whileStmt):
            return containsReturnStatement(whileStmt.body)
        case .forStatement(let forStmt):
            switch forStmt {
            case .range(let rangeFor):
                return containsReturnStatement(rangeFor.body)
            case .forEach(let forEach):
                return containsReturnStatement(forEach.body)
            }
        case .functionDeclaration(let funcDecl):
            return containsReturnStatement(funcDecl.body)
        case .procedureDeclaration(let procDecl):
            return containsReturnStatement(procDecl.body)
        case .variableDeclaration, .constantDeclaration, .assignment, .expressionStatement, .breakStatement:
            return false
        }
    }
}
