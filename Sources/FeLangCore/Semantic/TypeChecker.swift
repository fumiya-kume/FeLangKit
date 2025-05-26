import Foundation

/// Type checker for FE language expressions and type validation.
public final class TypeChecker: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let symbolTable: SymbolTable
    private var errors: [SemanticError] = []
    
    // MARK: - Initialization
    
    public init(symbolTable: SymbolTable) {
        self.symbolTable = symbolTable
    }
    
    // MARK: - Expression Type Checking
    
    /// Check the type of an expression and return the resulting type.
    public func checkExpression(_ expression: Expression) -> FeType {
        switch expression {
        case .literal(let literal):
            return checkLiteral(literal)
            
        case .identifier(let name, let position):
            return checkIdentifier(name: name, position: position)
            
        case .binary(let op, let left, let right, let position):
            return checkBinaryExpression(operator: op, left: left, right: right, position: position)
            
        case .unary(let op, let operand, let position):
            return checkUnaryExpression(operator: op, operand: operand, position: position)
            
        case .arrayAccess(let array, let indices, let position):
            return checkArrayAccess(array: array, indices: indices, position: position)
            
        case .fieldAccess(let record, let field, let position):
            return checkFieldAccess(record: record, field: field, position: position)
            
        case .functionCall(let name, let arguments, let position):
            return checkFunctionCall(name: name, arguments: arguments, position: position)
        }
    }
    
    // MARK: - Literal Type Checking
    
    private func checkLiteral(_ literal: Expression.Literal) -> FeType {
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
    
    // MARK: - Identifier Type Checking
    
    private func checkIdentifier(name: String, position: SourcePosition) -> FeType {
        guard let symbol = symbolTable.lookup(name) else {
            recordError(.undeclaredVariable(name, at: position))
            return .error
        }
        
        // Check if variable is initialized before use
        if !symbol.isInitialized && symbol.kind == .variable {
            recordError(.variableNotInitialized(name, at: position))
        }
        
        // Mark symbol as used
        _ = symbolTable.markAsUsed(name, at: position)
        
        return symbol.type
    }
    
    // MARK: - Binary Expression Type Checking
    
    private func checkBinaryExpression(operator op: Expression.BinaryOperator, left: Expression, right: Expression, position: SourcePosition) -> FeType {
        let leftType = checkExpression(left)
        let rightType = checkExpression(right)
        
        switch op {
        // Arithmetic operators
        case .add, .subtract, .multiply, .divide:
            return checkArithmeticOperation(op, leftType: leftType, rightType: rightType, position: position)
            
        case .modulo:
            return checkModuloOperation(leftType: leftType, rightType: rightType, position: position)
            
        case .power:
            return checkPowerOperation(leftType: leftType, rightType: rightType, position: position)
            
        // Comparison operators
        case .equal, .notEqual:
            return checkEqualityOperation(leftType: leftType, rightType: rightType, position: position)
            
        case .lessThan, .lessThanOrEqual, .greaterThan, .greaterThanOrEqual:
            return checkComparisonOperation(op, leftType: leftType, rightType: rightType, position: position)
            
        // Logical operators
        case .logicalAnd, .logicalOr:
            return checkLogicalOperation(op, leftType: leftType, rightType: rightType, position: position)
            
        // String operators
        case .concatenate:
            return checkConcatenationOperation(leftType: leftType, rightType: rightType, position: position)
        }
    }
    
    private func checkArithmeticOperation(_ op: Expression.BinaryOperator, leftType: FeType, rightType: FeType, position: SourcePosition) -> FeType {
        let numericTypes: Set<FeType> = [.integer, .real]
        
        guard numericTypes.contains(leftType) && numericTypes.contains(rightType) else {
            recordError(.incompatibleTypes(leftType, rightType, operation: op.description, at: position))
            return .error
        }
        
        // Real arithmetic if either operand is real
        if leftType == .real || rightType == .real {
            return .real
        }
        
        // Integer arithmetic for division can result in real
        if op == .divide {
            return .real
        }
        
        return .integer
    }
    
    private func checkModuloOperation(leftType: FeType, rightType: FeType, position: SourcePosition) -> FeType {
        guard leftType == .integer && rightType == .integer else {
            recordError(.incompatibleTypes(leftType, rightType, operation: "mod", at: position))
            return .error
        }
        
        return .integer
    }
    
    private func checkPowerOperation(leftType: FeType, rightType: FeType, position: SourcePosition) -> FeType {
        let numericTypes: Set<FeType> = [.integer, .real]
        
        guard numericTypes.contains(leftType) && numericTypes.contains(rightType) else {
            recordError(.incompatibleTypes(leftType, rightType, operation: "^", at: position))
            return .error
        }
        
        // Power operation typically results in real
        return .real
    }
    
    private func checkEqualityOperation(leftType: FeType, rightType: FeType, position: SourcePosition) -> FeType {
        guard leftType.isCompatible(with: rightType) else {
            recordError(.incompatibleTypes(leftType, rightType, operation: "equality", at: position))
            return .error
        }
        
        return .boolean
    }
    
    private func checkComparisonOperation(_ op: Expression.BinaryOperator, leftType: FeType, rightType: FeType, position: SourcePosition) -> FeType {
        let comparableTypes: Set<FeType> = [.integer, .real, .string, .character]
        
        guard comparableTypes.contains(leftType) && comparableTypes.contains(rightType) else {
            recordError(.incompatibleTypes(leftType, rightType, operation: op.description, at: position))
            return .error
        }
        
        // Types must be compatible for comparison
        guard leftType.isCompatible(with: rightType) else {
            recordError(.incompatibleTypes(leftType, rightType, operation: op.description, at: position))
            return .error
        }
        
        return .boolean
    }
    
    private func checkLogicalOperation(_ op: Expression.BinaryOperator, leftType: FeType, rightType: FeType, position: SourcePosition) -> FeType {
        guard leftType == .boolean && rightType == .boolean else {
            recordError(.incompatibleTypes(leftType, rightType, operation: op.description, at: position))
            return .error
        }
        
        return .boolean
    }
    
    private func checkConcatenationOperation(leftType: FeType, rightType: FeType, position: SourcePosition) -> FeType {
        guard leftType == .string && rightType == .string else {
            recordError(.incompatibleTypes(leftType, rightType, operation: "concatenation", at: position))
            return .error
        }
        
        return .string
    }
    
    // MARK: - Unary Expression Type Checking
    
    private func checkUnaryExpression(operator op: Expression.UnaryOperator, operand: Expression, position: SourcePosition) -> FeType {
        let operandType = checkExpression(operand)
        
        switch op {
        case .plus, .minus:
            return checkUnaryArithmeticOperation(op, operandType: operandType, position: position)
            
        case .logicalNot:
            return checkUnaryLogicalOperation(operandType: operandType, position: position)
        }
    }
    
    private func checkUnaryArithmeticOperation(_ op: Expression.UnaryOperator, operandType: FeType, position: SourcePosition) -> FeType {
        let numericTypes: Set<FeType> = [.integer, .real]
        
        guard numericTypes.contains(operandType) else {
            recordError(.incompatibleTypes(operandType, .integer, operation: op.description, at: position))
            return .error
        }
        
        return operandType
    }
    
    private func checkUnaryLogicalOperation(operandType: FeType, position: SourcePosition) -> FeType {
        guard operandType == .boolean else {
            recordError(.typeMismatch(expected: .boolean, actual: operandType, at: position))
            return .error
        }
        
        return .boolean
    }
    
    // MARK: - Array Access Type Checking
    
    private func checkArrayAccess(array: Expression, indices: [Expression], position: SourcePosition) -> FeType {
        let arrayType = checkExpression(array)
        
        guard case .array(let elementType, let dimensions) = arrayType else {
            recordError(.invalidArrayAccess(at: position))
            return .error
        }
        
        // Check number of indices matches dimensions
        guard indices.count == dimensions.count else {
            recordError(.invalidArrayDimension(at: position))
            return .error
        }
        
        // Check each index is integer type
        for index in indices {
            let indexType = checkExpression(index)
            if !indexType.isCompatible(with: .integer) {
                recordError(.arrayIndexTypeMismatch(expected: .integer, actual: indexType, at: position))
            }
        }
        
        return elementType
    }
    
    // MARK: - Field Access Type Checking
    
    private func checkFieldAccess(record: Expression, field: String, position: SourcePosition) -> FeType {
        let recordType = checkExpression(record)
        
        guard case .record(let recordName, let fields) = recordType else {
            recordError(.invalidFieldAccess(at: position))
            return .error
        }
        
        guard let fieldType = fields[field] else {
            recordError(.undeclaredField(fieldName: field, recordType: recordName, at: position))
            return .error
        }
        
        return fieldType
    }
    
    // MARK: - Function Call Type Checking
    
    private func checkFunctionCall(name: String, arguments: [Expression], position: SourcePosition) -> FeType {
        guard let symbol = symbolTable.lookup(name) else {
            recordError(.undeclaredFunction(name, at: position))
            return .error
        }
        
        guard case .function(let paramTypes, let returnType) = symbol.type else {
            recordError(.undeclaredFunction(name, at: position))
            return .error
        }
        
        // Check argument count
        guard arguments.count == paramTypes.count else {
            recordError(.incorrectArgumentCount(function: name, expected: paramTypes.count, actual: arguments.count, at: position))
            return .error
        }
        
        // Check argument types
        for (index, (argument, expectedType)) in zip(arguments, paramTypes).enumerated() {
            let argumentType = checkExpression(argument)
            if !argumentType.canAssignTo(expectedType) {
                recordError(.argumentTypeMismatch(function: name, paramIndex: index, expected: expectedType, actual: argumentType, at: position))
            }
        }
        
        // Mark function as used
        _ = symbolTable.markAsUsed(name, at: position)
        
        return returnType ?? .void
    }
    
    // MARK: - Type Compatibility Checking
    
    /// Check if a value can be assigned to a variable of the target type.
    public func canAssign(valueType: FeType, to targetType: FeType) -> Bool {
        return valueType.canAssignTo(targetType)
    }
    
    /// Check if two types are compatible for operations.
    public func areCompatible(_ type1: FeType, _ type2: FeType) -> Bool {
        return type1.isCompatible(with: type2)
    }
    
    /// Infer the type of a literal expression.
    public func inferLiteralType(_ literal: Expression.Literal) -> FeType {
        return checkLiteral(literal)
    }
    
    // MARK: - Error Handling
    
    private func recordError(_ error: SemanticError) {
        errors.append(error)
    }
    
    /// Get all errors collected during type checking.
    public func getErrors() -> [SemanticError] {
        return errors
    }
    
    /// Clear all collected errors.
    public func clearErrors() {
        errors.removeAll()
    }
}

// MARK: - Extensions for Operator Descriptions

extension Expression.BinaryOperator {
    var description: String {
        switch self {
        case .add: return "+"
        case .subtract: return "-"
        case .multiply: return "*"
        case .divide: return "/"
        case .modulo: return "mod"
        case .power: return "^"
        case .equal: return "="
        case .notEqual: return "<>"
        case .lessThan: return "<"
        case .lessThanOrEqual: return "<="
        case .greaterThan: return ">"
        case .greaterThanOrEqual: return ">="
        case .logicalAnd: return "and"
        case .logicalOr: return "or"
        case .concatenate: return "&"
        }
    }
}

extension Expression.UnaryOperator {
    var description: String {
        switch self {
        case .plus: return "+"
        case .minus: return "-"
        case .logicalNot: return "not"
        }
    }
}