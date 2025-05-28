import Foundation

/// Errors that can occur during semantic analysis.
public enum SemanticError: Error, Equatable, Sendable {
    // Type-related errors
    case typeMismatch(expected: FeType, actual: FeType, at: SourcePosition)
    case incompatibleTypes(FeType, FeType, operation: String, at: SourcePosition)
    case unknownType(String, at: SourcePosition)
    case invalidTypeConversion(from: FeType, to: FeType, at: SourcePosition)

    // Variable/scope-related errors
    case undeclaredVariable(String, at: SourcePosition)
    case variableAlreadyDeclared(String, at: SourcePosition)
    case variableNotInitialized(String, at: SourcePosition)
    case constantReassignment(String, at: SourcePosition)
    case invalidAssignmentTarget(at: SourcePosition)

    // Function-related errors
    case undeclaredFunction(String, at: SourcePosition)
    case functionAlreadyDeclared(String, at: SourcePosition)
    case incorrectArgumentCount(function: String, expected: Int, actual: Int, at: SourcePosition)
    case argumentTypeMismatch(function: String, paramIndex: Int, expected: FeType, actual: FeType, at: SourcePosition)
    case missingReturnStatement(function: String, at: SourcePosition)
    case returnTypeMismatch(function: String, expected: FeType, actual: FeType, at: SourcePosition)
    case voidFunctionReturnsValue(function: String, at: SourcePosition)

    // Control flow errors
    case unreachableCode(at: SourcePosition)
    case breakOutsideLoop(at: SourcePosition)
    case returnOutsideFunction(at: SourcePosition)

    // Array/indexing errors
    case invalidArrayAccess(at: SourcePosition)
    case arrayIndexTypeMismatch(expected: FeType, actual: FeType, at: SourcePosition)
    case invalidArrayDimension(at: SourcePosition)

    // Record/field errors
    case undeclaredField(fieldName: String, recordType: String, at: SourcePosition)
    case invalidFieldAccess(at: SourcePosition)

    // Analysis limitations
    case cyclicDependency([String], at: SourcePosition)
    case analysisDepthExceeded(at: SourcePosition)
    case tooManyErrors(count: Int)
}

/// Type system for FE language semantic analysis.
public indirect enum FeType: Equatable, Sendable, CustomStringConvertible {
    case integer
    case real
    case string
    case character
    case boolean
    case array(elementType: FeType, dimensions: [Int])
    case record(name: String, fields: [String: FeType])
    case function(parameters: [FeType], returnType: FeType?)
    case void
    case unknown
    case error // Used for error recovery

    public var description: String {
        switch self {
        case .integer:
            return "integer"
        case .real:
            return "real"
        case .string:
            return "string"
        case .character:
            return "character"
        case .boolean:
            return "boolean"
        case .array(let elementType, let dimensions):
            let dimStr = dimensions.map { "[\($0)]" }.joined()
            return "array\(dimStr) of \(elementType)"
        case .record(let name, _):
            return "record \(name)"
        case .function(let params, let returnType):
            let paramStr = params.map { $0.description }.joined(separator: ", ")
            if let ret = returnType {
                return "function(\(paramStr)) -> \(ret)"
            } else {
                return "procedure(\(paramStr))"
            }
        case .void:
            return "void"
        case .unknown:
            return "unknown"
        case .error:
            return "error"
        }
    }

    /// Check if this type is compatible with another type.
    public func isCompatible(with other: FeType) -> Bool {
        switch (self, other) {
        case (.error, _), (_, .error):
            return true // Error type is compatible with everything for recovery
        case (.unknown, _), (_, .unknown):
            return true // Unknown type is compatible during inference
        case (.integer, .integer), (.real, .real), (.string, .string),
             (.character, .character), (.boolean, .boolean), (.void, .void):
            return true
        case (.integer, .real), (.real, .integer):
            return true // Numeric types are compatible
        case (.array(let e1, let d1), .array(let e2, let d2)):
            return e1.isCompatible(with: e2) && d1 == d2
        case (.record(let n1, let f1), .record(let n2, let f2)):
            return n1 == n2 && f1 == f2
        case (.function(let p1, let r1), .function(let p2, let r2)):
            return p1.count == p2.count &&
                   zip(p1, p2).allSatisfy { $0.0.isCompatible(with: $0.1) } &&
                   compatibleReturnTypes(r1, r2)
        default:
            return false
        }
    }

    /// Check if this type can be assigned to another type.
    public func canAssignTo(_ target: FeType) -> Bool {
        switch (self, target) {
        case (.error, _), (_, .error):
            return true // Error type for recovery
        case (.unknown, _), (_, .unknown):
            return true // Unknown type during inference
        case (.integer, .real):
            return true // Implicit integer to real conversion
        default:
            return self.isCompatible(with: target)
        }
    }

    private func compatibleReturnTypes(_ r1: FeType?, _ r2: FeType?) -> Bool {
        switch (r1, r2) {
        case (.none, .none):
            return true
        case (.some(let t1), .some(let t2)):
            return t1.isCompatible(with: t2)
        default:
            return false
        }
    }
}

extension SemanticError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .typeMismatch(let expected, let actual, let pos):
            return "Type mismatch at \(pos): expected '\(expected)', got '\(actual)'"
        case .incompatibleTypes(let t1, let t2, let op, let pos):
            return "Incompatible types '\(t1)' and '\(t2)' for operation '\(op)' at \(pos)"
        case .unknownType(let name, let pos):
            return "Unknown type '\(name)' at \(pos)"
        case .invalidTypeConversion(let from, let to, let pos):
            return "Invalid type conversion from '\(from)' to '\(to)' at \(pos)"
        case .undeclaredVariable(let name, let pos):
            return "Undeclared variable '\(name)' at \(pos)"
        case .variableAlreadyDeclared(let name, let pos):
            return "Variable '\(name)' already declared at \(pos)"
        case .variableNotInitialized(let name, let pos):
            return "Variable '\(name)' used before initialization at \(pos)"
        case .constantReassignment(let name, let pos):
            return "Cannot reassign constant '\(name)' at \(pos)"
        case .invalidAssignmentTarget(let pos):
            return "Invalid assignment target at \(pos)"
        case .undeclaredFunction(let name, let pos):
            return "Undeclared function '\(name)' at \(pos)"
        case .functionAlreadyDeclared(let name, let pos):
            return "Function '\(name)' already declared at \(pos)"
        case .incorrectArgumentCount:
            return "Function argument count error"
        case .argumentTypeMismatch:
            return "Function argument type mismatch"
        case .missingReturnStatement:
            return "Missing return statement"
        case .returnTypeMismatch:
            return "Return type mismatch"
        case .voidFunctionReturnsValue:
            return "Void function returns value"
        case .unreachableCode(let pos):
            return "Unreachable code at \(pos)"
        case .breakOutsideLoop(let pos):
            return "Break statement outside loop at \(pos)"
        case .returnOutsideFunction(let pos):
            return "Return statement outside function at \(pos)"
        case .invalidArrayAccess(let pos):
            return "Invalid array access at \(pos)"
        case .arrayIndexTypeMismatch(let expected, let actual, let pos):
            return "Array index type mismatch: expected '\(expected)', got '\(actual)' at \(pos)"
        case .invalidArrayDimension(let pos):
            return "Invalid array dimension at \(pos)"
        case .undeclaredField:
            return "Undeclared field error"
        case .invalidFieldAccess(let pos):
            return "Invalid field access at \(pos)"
        case .cyclicDependency:
            return "Cyclic dependency detected"
        case .analysisDepthExceeded(let pos):
            return "Analysis depth exceeded at \(pos)"
        case .tooManyErrors:
            return "Too many semantic errors, stopping analysis"
        }
    }
}

/// Represents the result of semantic analysis.
public struct SemanticAnalysisResult: Sendable {
    public let isSuccessful: Bool
    public let errors: [SemanticError]
    public let warnings: [SemanticWarning]
    public let symbolTable: SymbolTable

    public init(
        isSuccessful: Bool,
        errors: [SemanticError] = [],
        warnings: [SemanticWarning] = [],
        symbolTable: SymbolTable
    ) {
        self.isSuccessful = isSuccessful
        self.errors = errors
        self.warnings = warnings
        self.symbolTable = symbolTable
    }

    /// Whether there are any errors.
    public var hasErrors: Bool {
        return !errors.isEmpty
    }

    /// Whether there are any warnings.
    public var hasWarnings: Bool {
        return !warnings.isEmpty
    }

    /// Total number of issues (errors + warnings).
    public var issueCount: Int {
        return errors.count + warnings.count
    }
}

/// Warnings that can occur during semantic analysis.
public enum SemanticWarning: Equatable, Sendable {
    case unusedVariable(String, at: SourcePosition)
    case unusedFunction(String, at: SourcePosition)
    case unreachableCode(at: SourcePosition)
    case implicitTypeConversion(from: FeType, to: FeType, at: SourcePosition)
    case shadowedVariable(String, at: SourcePosition)
    case inefficientOperation(description: String, at: SourcePosition)
}

extension SemanticWarning {
    public var description: String {
        switch self {
        case .unusedVariable(let name, let pos):
            return "Unused variable '\(name)' at \(pos)"
        case .unusedFunction(let name, let pos):
            return "Unused function '\(name)' at \(pos)"
        case .unreachableCode(let pos):
            return "Unreachable code at \(pos)"
        case .implicitTypeConversion(let from, let to, let pos):
            return "Implicit type conversion from '\(from)' to '\(to)' at \(pos)"
        case .shadowedVariable(let name, let pos):
            return "Variable '\(name)' shadows variable in outer scope at \(pos)"
        case .inefficientOperation(let desc, let pos):
            return "Inefficient operation: \(desc) at \(pos)"
        }
    }
}
