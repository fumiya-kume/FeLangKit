import Foundation

public enum TypeTag: Int, Equatable, Sendable {
    case integer = 0
    case real = 1
    case string = 2
    case character = 3
    case boolean = 4
    case array = 5
    case record = 6
    case function = 7
    case null = 8
}

public enum BoxingKind: Equatable, Sendable {
    case box(sourceType: FeType)
    case unbox(targetType: FeType)
}

public struct BoxingBoundary: Equatable, Sendable {
    public let kind: BoxingKind
    public let position: SourcePosition

    public init(kind: BoxingKind, position: SourcePosition) {
        self.kind = kind
        self.position = position
    }
}

public struct ABILoweringResult: Equatable, Sendable {
    public let boundaries: [BoxingBoundary]
    public let diagnostics: [String]

    public init(boundaries: [BoxingBoundary], diagnostics: [String]) {
        self.boundaries = boundaries
        self.diagnostics = diagnostics
    }

    public var requiresBoxing: Bool {
        return !boundaries.isEmpty
    }
}

public struct ABILowering: Sendable {

    public init() {}

    public func analyze(_ statements: [Statement]) -> ABILoweringResult {
        var boundaries: [BoxingBoundary] = []
        var diagnostics: [String] = []
        for statement in statements {
            analyzeStatement(statement, boundaries: &boundaries, diagnostics: &diagnostics)
        }
        return ABILoweringResult(boundaries: boundaries, diagnostics: diagnostics)
    }

    public static func needsBoxing(source: FeType, target: FeType) -> Bool {
        switch (source, target) {
        case (.nullable, _), (_, .nullable):
            return !source.isNullable && target.isNullable
        case (_, .any):
            return true
        default:
            return false
        }
    }

    public static func needsUnboxing(source: FeType, target: FeType) -> Bool {
        switch (source, target) {
        case (.any, _) where !target.isNullable && target != .any && target != .unknown && target != .error:
            return true
        case (.nullable, _) where !target.isNullable && target != .unknown && target != .error:
            return true
        default:
            return false
        }
    }

    public static func typeTag(for type: FeType) -> TypeTag {
        switch type {
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
        case .array:
            return .array
        case .record:
            return .record
        case .function:
            return .function
        case .nullable(let inner):
            return typeTag(for: inner)
        default:
            return .null
        }
    }

    private func analyzeStatement(
        _ statement: Statement,
        boundaries: inout [BoxingBoundary],
        diagnostics: inout [String]
    ) {
        switch statement {
        case .variableDeclaration(let decl):
            analyzeVariableDeclaration(decl, boundaries: &boundaries, diagnostics: &diagnostics)
        case .functionDeclaration(let decl):
            analyzeFunctionDeclaration(decl, boundaries: &boundaries, diagnostics: &diagnostics)
        case .procedureDeclaration(let decl):
            analyzeProcedureDeclaration(decl, boundaries: &boundaries, diagnostics: &diagnostics)
        case .ifStatement(let ifStmt):
            for bodyStmt in ifStmt.thenBody { analyzeStatement(bodyStmt, boundaries: &boundaries, diagnostics: &diagnostics) }
            for elseIf in ifStmt.elseIfs {
                for bodyStmt in elseIf.body { analyzeStatement(bodyStmt, boundaries: &boundaries, diagnostics: &diagnostics) }
            }
            if let elseBody = ifStmt.elseBody {
                for bodyStmt in elseBody { analyzeStatement(bodyStmt, boundaries: &boundaries, diagnostics: &diagnostics) }
            }
        case .whileStatement(let whileStmt):
            for bodyStmt in whileStmt.body { analyzeStatement(bodyStmt, boundaries: &boundaries, diagnostics: &diagnostics) }
        case .doWhileStatement(let doWhileStmt):
            for bodyStmt in doWhileStmt.body { analyzeStatement(bodyStmt, boundaries: &boundaries, diagnostics: &diagnostics) }
        case .forStatement(let forStmt):
            switch forStmt {
            case .range(let rangeFor):
                for bodyStmt in rangeFor.body { analyzeStatement(bodyStmt, boundaries: &boundaries, diagnostics: &diagnostics) }
            case .forEach(let forEach):
                for bodyStmt in forEach.body { analyzeStatement(bodyStmt, boundaries: &boundaries, diagnostics: &diagnostics) }
            }
        case .block(let stmts):
            for bodyStmt in stmts { analyzeStatement(bodyStmt, boundaries: &boundaries, diagnostics: &diagnostics) }
        case .globalDeclaration(let decl):
            analyzeGlobalDeclaration(decl, boundaries: &boundaries, diagnostics: &diagnostics)
        default:
            break
        }
    }

    private func analyzeVariableDeclaration(
        _ decl: VariableDeclaration,
        boundaries: inout [BoxingBoundary],
        diagnostics: inout [String]
    ) {
        let declType = decl.type
        let position = decl.position ?? SourcePosition(line: 0, column: 0, offset: 0)
        checkDeclarationType(declType, position: position, boundaries: &boundaries, diagnostics: &diagnostics)
    }

    private func analyzeGlobalDeclaration(
        _ decl: GlobalDeclaration,
        boundaries: inout [BoxingBoundary],
        diagnostics: inout [String]
    ) {
        let declType = decl.type
        let position = decl.position ?? SourcePosition(line: 0, column: 0, offset: 0)
        checkDeclarationType(declType, position: position, boundaries: &boundaries, diagnostics: &diagnostics)
    }

    private func analyzeFunctionDeclaration(
        _ decl: FunctionDeclaration,
        boundaries: inout [BoxingBoundary],
        diagnostics: inout [String]
    ) {
        let position = decl.position ?? SourcePosition(line: 0, column: 0, offset: 0)
        for param in decl.parameters {
            checkDeclarationType(param.type, position: position, boundaries: &boundaries, diagnostics: &diagnostics)
        }
        if let returnType = decl.returnType {
            checkDeclarationType(returnType, position: position, boundaries: &boundaries, diagnostics: &diagnostics)
        }
        for stmt in decl.body {
            analyzeStatement(stmt, boundaries: &boundaries, diagnostics: &diagnostics)
        }
    }

    private func analyzeProcedureDeclaration(
        _ decl: ProcedureDeclaration,
        boundaries: inout [BoxingBoundary],
        diagnostics: inout [String]
    ) {
        let position = decl.position ?? SourcePosition(line: 0, column: 0, offset: 0)
        for param in decl.parameters {
            checkDeclarationType(param.type, position: position, boundaries: &boundaries, diagnostics: &diagnostics)
        }
        for stmt in decl.body {
            analyzeStatement(stmt, boundaries: &boundaries, diagnostics: &diagnostics)
        }
    }

    private func checkDeclarationType(
        _ dataType: DataType,
        position: SourcePosition,
        boundaries: inout [BoxingBoundary],
        diagnostics: inout [String]
    ) {
        switch dataType {
        case .nullable(let inner):
            let innerFeType = dataTypeToFeType(inner)
            boundaries.append(BoxingBoundary(
                kind: .box(sourceType: innerFeType),
                position: position
            ))
            diagnostics.append("boxing boundary: \(inner) -> \(dataType)")
        case .any:
            boundaries.append(BoxingBoundary(
                kind: .box(sourceType: .any),
                position: position
            ))
            diagnostics.append("boxing boundary: Any at \(position)")
        default:
            break
        }
    }

    private func dataTypeToFeType(_ dataType: DataType) -> FeType {
        switch dataType {
        case .integer: return .integer
        case .real: return .real
        case .character: return .character
        case .string: return .string
        case .boolean: return .boolean
        case .array(let elementType): return .array(elementType: dataTypeToFeType(elementType), dimensions: [])
        case .record(let name): return .record(name: name, fields: [:])
        case .nullable(let inner): return .nullable(dataTypeToFeType(inner))
        case .any: return .any
        }
    }
}

public struct BoxingOperations: Sendable {

    public init() {}

    public static func boxDescription(value: String, sourceType: FeType) -> String {
        let tag = ABILowering.typeTag(for: sourceType)
        return "box(\(value), tag=\(tag))"
    }

    public static func unboxDescription(value: String, targetType: FeType) -> String {
        let tag = ABILowering.typeTag(for: targetType)
        return "unbox(\(value), expected_tag=\(tag))"
    }
}
