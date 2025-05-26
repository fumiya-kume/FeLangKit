import Foundation

/// Main coordinator for semantic analysis of FE language AST.
public final class SemanticAnalyzer: @unchecked Sendable {
    
    // MARK: - Configuration
    
    /// Configuration options for semantic analysis.
    public struct AnalysisOptions: Sendable {
        /// Maximum number of errors before stopping analysis.
        public let maxErrors: Int
        
        /// Whether to collect warnings in addition to errors.
        public let collectWarnings: Bool
        
        /// Whether to perform optimization analysis.
        public let performOptimizations: Bool
        
        /// Maximum analysis depth to prevent infinite recursion.
        public let maxAnalysisDepth: Int
        
        public init(
            maxErrors: Int = 100,
            collectWarnings: Bool = true,
            performOptimizations: Bool = false,
            maxAnalysisDepth: Int = 1000
        ) {
            self.maxErrors = maxErrors
            self.collectWarnings = collectWarnings
            self.performOptimizations = performOptimizations
            self.maxAnalysisDepth = maxAnalysisDepth
        }
    }
    
    // MARK: - Properties
    
    private let options: AnalysisOptions
    private let symbolTable: SymbolTable
    private let typeChecker: TypeChecker
    private var errors: [SemanticError] = []
    private var warnings: [SemanticWarning] = []
    private var analysisDepth: Int = 0
    
    // MARK: - Initialization
    
    public init(options: AnalysisOptions = AnalysisOptions()) {
        self.options = options
        self.symbolTable = SymbolTable()
        self.typeChecker = TypeChecker(symbolTable: symbolTable)
    }
    
    // MARK: - Public Interface
    
    /// Perform semantic analysis on a list of statements.
    public func analyze(statements: [Statement]) -> SemanticAnalysisResult {
        // Reset state for new analysis
        errors.removeAll()
        warnings.removeAll()
        analysisDepth = 0
        
        // Analyze each statement
        for statement in statements {
            if errors.count >= options.maxErrors {
                errors.append(.tooManyErrors(count: errors.count))
                break
            }
            
            analyzeStatement(statement)
        }
        
        // Collect warnings if enabled
        if options.collectWarnings {
            collectWarnings()
        }
        
        return SemanticAnalysisResult(
            isSuccessful: errors.isEmpty,
            errors: errors,
            warnings: warnings,
            symbolTable: symbolTable
        )
    }
    
    // MARK: - Statement Analysis
    
    private func analyzeStatement(_ statement: Statement) {
        guard incrementDepth() else { return }
        defer { decrementDepth() }
        
        switch statement {
        case .variableDeclaration(let name, let dataType, let initialValue, let position):
            analyzeVariableDeclaration(name: name, dataType: dataType, initialValue: initialValue, position: position)
            
        case .constantDeclaration(let name, let dataType, let value, let position):
            analyzeConstantDeclaration(name: name, dataType: dataType, value: value, position: position)
            
        case .functionDeclaration(let name, let parameters, let returnType, let body, let position):
            analyzeFunctionDeclaration(name: name, parameters: parameters, returnType: returnType, body: body, position: position)
            
        case .procedureDeclaration(let name, let parameters, let body, let position):
            analyzeProcedureDeclaration(name: name, parameters: parameters, body: body, position: position)
            
        case .assignment(let target, let value, let position):
            analyzeAssignment(target: target, value: value, position: position)
            
        case .ifStatement(let condition, let thenBranch, let elseBranch, let position):
            analyzeIfStatement(condition: condition, thenBranch: thenBranch, elseBranch: elseBranch, position: position)
            
        case .whileStatement(let condition, let body, let position):
            analyzeWhileStatement(condition: condition, body: body, position: position)
            
        case .forStatement(let variable, let range, let body, let position):
            analyzeForStatement(variable: variable, range: range, body: body, position: position)
            
        case .returnStatement(let value, let position):
            analyzeReturnStatement(value: value, position: position)
            
        case .breakStatement(let position):
            analyzeBreakStatement(position: position)
            
        case .expressionStatement(let expression, _):
            _ = typeChecker.checkExpression(expression)
            
        case .block(let statements, _):
            analyzeBlock(statements)
        }
    }
    
    // MARK: - Declaration Analysis
    
    private func analyzeVariableDeclaration(name: String, dataType: DataType?, initialValue: Expression?, position: SourcePosition) {
        // Determine the variable type
        let variableType: FeType
        
        if let dataType = dataType {
            variableType = convertDataTypeToFeType(dataType)
        } else if let initialValue = initialValue {
            // Type inference from initial value
            let valueType = typeChecker.checkExpression(initialValue)
            variableType = valueType
        } else {
            recordError(.unknownType("Cannot infer type for variable '\(name)'", at: position))
            variableType = .error
        }
        
        // Declare the variable in symbol table
        let declareResult = symbolTable.declare(
            name: name,
            type: variableType,
            kind: .variable,
            position: position,
            isInitialized: initialValue != nil
        )
        
        if case .failure(let error) = declareResult {
            recordError(error)
        }
        
        // Type check initial value if present
        if let initialValue = initialValue {
            let valueType = typeChecker.checkExpression(initialValue)
            if !valueType.canAssignTo(variableType) {
                recordError(.typeMismatch(expected: variableType, actual: valueType, at: position))
            }
        }
    }
    
    private func analyzeConstantDeclaration(name: String, dataType: DataType?, value: Expression, position: SourcePosition) {
        // Type check the value expression
        let valueType = typeChecker.checkExpression(value)
        
        // Determine the constant type
        let constantType: FeType
        if let dataType = dataType {
            constantType = convertDataTypeToFeType(dataType)
            // Check assignment compatibility
            if !valueType.canAssignTo(constantType) {
                recordError(.typeMismatch(expected: constantType, actual: valueType, at: position))
            }
        } else {
            // Use inferred type from value
            constantType = valueType
        }
        
        // Declare the constant in symbol table
        let declareResult = symbolTable.declare(
            name: name,
            type: constantType,
            kind: .constant,
            position: position,
            isInitialized: true
        )
        
        if case .failure(let error) = declareResult {
            recordError(error)
        }
    }
    
    private func analyzeFunctionDeclaration(name: String, parameters: [Statement.Parameter], returnType: DataType?, body: [Statement], position: SourcePosition) {
        let paramTypes = parameters.map { convertDataTypeToFeType($0.type) }
        let retType = returnType.map { convertDataTypeToFeType($0) }
        let functionType = FeType.function(parameters: paramTypes, returnType: retType)
        
        // Declare function in current scope
        let declareResult = symbolTable.declare(
            name: name,
            type: functionType,
            kind: .function,
            position: position,
            isInitialized: true
        )
        
        if case .failure(let error) = declareResult {
            recordError(error)
        }
        
        // Create function scope and analyze body
        let functionScope = symbolTable.pushScope(kind: .function(name: name, returnType: retType))
        
        // Add parameters to function scope
        for parameter in parameters {
            let paramType = convertDataTypeToFeType(parameter.type)
            let paramResult = symbolTable.declare(
                name: parameter.name,
                type: paramType,
                kind: .parameter,
                position: position,
                isInitialized: true
            )
            
            if case .failure(let error) = paramResult {
                recordError(error)
            }
        }
        
        // Analyze function body
        analyzeBlock(body)
        
        // Check for return statement if function has return type
        if retType != nil {
            checkReturnStatements(in: body, expectedType: retType, functionName: name, position: position)
        }
        
        symbolTable.popScope()
    }
    
    private func analyzeProcedureDeclaration(name: String, parameters: [Statement.Parameter], body: [Statement], position: SourcePosition) {
        let paramTypes = parameters.map { convertDataTypeToFeType($0.type) }
        let procedureType = FeType.function(parameters: paramTypes, returnType: nil)
        
        // Declare procedure in current scope
        let declareResult = symbolTable.declare(
            name: name,
            type: procedureType,
            kind: .procedure,
            position: position,
            isInitialized: true
        )
        
        if case .failure(let error) = declareResult {
            recordError(error)
        }
        
        // Create procedure scope and analyze body
        symbolTable.pushScope(kind: .procedure(name: name))
        
        // Add parameters to procedure scope
        for parameter in parameters {
            let paramType = convertDataTypeToFeType(parameter.type)
            let paramResult = symbolTable.declare(
                name: parameter.name,
                type: paramType,
                kind: .parameter,
                position: position,
                isInitialized: true
            )
            
            if case .failure(let error) = paramResult {
                recordError(error)
            }
        }
        
        // Analyze procedure body
        analyzeBlock(body)
        
        symbolTable.popScope()
    }
    
    // MARK: - Control Flow Analysis
    
    private func analyzeAssignment(target: Statement.AssignmentTarget, value: Expression, position: SourcePosition) {
        let valueType = typeChecker.checkExpression(value)
        
        switch target {
        case .variable(let name):
            guard let symbol = symbolTable.lookup(name) else {
                recordError(.undeclaredVariable(name, at: position))
                return
            }
            
            // Check if constant reassignment
            if symbol.kind == .constant {
                recordError(.constantReassignment(name, at: position))
                return
            }
            
            // Check type compatibility
            if !valueType.canAssignTo(symbol.type) {
                recordError(.typeMismatch(expected: symbol.type, actual: valueType, at: position))
            }
            
            // Mark as initialized
            _ = symbolTable.markAsInitialized(name, at: position)
            
        case .arrayElement(let arrayName, let indices):
            guard let arraySymbol = symbolTable.lookup(arrayName) else {
                recordError(.undeclaredVariable(arrayName, at: position))
                return
            }
            
            // Validate array access
            if case .array(let elementType, let dimensions) = arraySymbol.type {
                if indices.count != dimensions.count {
                    recordError(.invalidArrayDimension(at: position))
                    return
                }
                
                // Check index types
                for index in indices {
                    let indexType = typeChecker.checkExpression(index)
                    if !indexType.isCompatible(with: .integer) {
                        recordError(.arrayIndexTypeMismatch(expected: .integer, actual: indexType, at: position))
                    }
                }
                
                // Check assignment type compatibility
                if !valueType.canAssignTo(elementType) {
                    recordError(.typeMismatch(expected: elementType, actual: valueType, at: position))
                }
            } else {
                recordError(.invalidArrayAccess(at: position))
            }
        }
    }
    
    private func analyzeIfStatement(condition: Expression, thenBranch: [Statement], elseBranch: [Statement]?, position: SourcePosition) {
        // Check condition type
        let conditionType = typeChecker.checkExpression(condition)
        if !conditionType.isCompatible(with: .boolean) {
            recordError(.typeMismatch(expected: .boolean, actual: conditionType, at: position))
        }
        
        // Analyze branches
        symbolTable.pushScope(kind: .block)
        analyzeBlock(thenBranch)
        symbolTable.popScope()
        
        if let elseBranch = elseBranch {
            symbolTable.pushScope(kind: .block)
            analyzeBlock(elseBranch)
            symbolTable.popScope()
        }
    }
    
    private func analyzeWhileStatement(condition: Expression, body: [Statement], position: SourcePosition) {
        // Check condition type
        let conditionType = typeChecker.checkExpression(condition)
        if !conditionType.isCompatible(with: .boolean) {
            recordError(.typeMismatch(expected: .boolean, actual: conditionType, at: position))
        }
        
        // Analyze loop body
        symbolTable.pushScope(kind: .loop)
        analyzeBlock(body)
        symbolTable.popScope()
    }
    
    private func analyzeForStatement(variable: String, range: Statement.ForRange, body: [Statement], position: SourcePosition) {
        symbolTable.pushScope(kind: .loop)
        
        switch range {
        case .range(let start, let end):
            // Check range bounds are integers
            let startType = typeChecker.checkExpression(start)
            let endType = typeChecker.checkExpression(end)
            
            if !startType.isCompatible(with: .integer) {
                recordError(.typeMismatch(expected: .integer, actual: startType, at: position))
            }
            if !endType.isCompatible(with: .integer) {
                recordError(.typeMismatch(expected: .integer, actual: endType, at: position))
            }
            
            // Declare loop variable
            _ = symbolTable.declare(
                name: variable,
                type: .integer,
                kind: .variable,
                position: position,
                isInitialized: true
            )
            
        case .forEach(let iterable):
            let iterableType = typeChecker.checkExpression(iterable)
            
            // Determine element type from iterable
            let elementType: FeType
            if case .array(let elemType, _) = iterableType {
                elementType = elemType
            } else {
                recordError(.invalidArrayAccess(at: position))
                elementType = .error
            }
            
            // Declare loop variable with element type
            _ = symbolTable.declare(
                name: variable,
                type: elementType,
                kind: .variable,
                position: position,
                isInitialized: true
            )
        }
        
        analyzeBlock(body)
        symbolTable.popScope()
    }
    
    private func analyzeReturnStatement(value: Expression?, position: SourcePosition) {
        guard symbolTable.isInFunction else {
            recordError(.returnOutsideFunction(at: position))
            return
        }
        
        guard let currentFunction = symbolTable.currentFunction else {
            recordError(.returnOutsideFunction(at: position))
            return
        }
        
        let expectedReturnType = currentFunction.returnType
        
        if let value = value {
            let returnType = typeChecker.checkExpression(value)
            
            if let expectedType = expectedReturnType {
                if !returnType.canAssignTo(expectedType) {
                    recordError(.returnTypeMismatch(function: currentFunction.name, expected: expectedType, actual: returnType, at: position))
                }
            } else {
                recordError(.voidFunctionReturnsValue(function: currentFunction.name, at: position))
            }
        } else {
            if expectedReturnType != nil {
                recordError(.missingReturnStatement(function: currentFunction.name, at: position))
            }
        }
    }
    
    private func analyzeBreakStatement(position: SourcePosition) {
        if !symbolTable.isInLoop {
            recordError(.breakOutsideLoop(at: position))
        }
    }
    
    private func analyzeBlock(_ statements: [Statement]) {
        for statement in statements {
            analyzeStatement(statement)
        }
    }
    
    // MARK: - Helper Methods
    
    private func convertDataTypeToFeType(_ dataType: DataType) -> FeType {
        switch dataType {
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
        case .array(let elementType, let size):
            let feElementType = convertDataTypeToFeType(elementType)
            return .array(elementType: feElementType, dimensions: [size])
        case .record(let name, let fields):
            let feFields = fields.mapValues { convertDataTypeToFeType($0) }
            return .record(name: name, fields: feFields)
        }
    }
    
    private func checkReturnStatements(in statements: [Statement], expectedType: FeType?, functionName: String, position: SourcePosition) {
        var hasReturn = false
        
        for statement in statements {
            if case .returnStatement = statement {
                hasReturn = true
                break
            }
            // TODO: Add more sophisticated control flow analysis
        }
        
        if !hasReturn && expectedType != nil {
            recordError(.missingReturnStatement(function: functionName, at: position))
        }
    }
    
    private func incrementDepth() -> Bool {
        analysisDepth += 1
        if analysisDepth > options.maxAnalysisDepth {
            recordError(.analysisDepthExceeded(at: SourcePosition(line: 0, column: 0, offset: 0)))
            return false
        }
        return true
    }
    
    private func decrementDepth() {
        analysisDepth -= 1
    }
    
    private func recordError(_ error: SemanticError) {
        if errors.count < options.maxErrors {
            errors.append(error)
        }
    }
    
    private func collectWarnings() {
        // Collect unused variable warnings
        let unusedSymbols = symbolTable.getUnusedSymbols()
        for symbol in unusedSymbols {
            warnings.append(.unusedVariable(symbol.name, at: symbol.position))
        }
    }
}