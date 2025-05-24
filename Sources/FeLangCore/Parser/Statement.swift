/// Represents statements in FE pseudo-language.
public indirect enum Statement: Equatable, Codable, Sendable {
    // Control flow
    case ifStatement(IfStatement)
    case whileStatement(WhileStatement)
    case forStatement(ForStatement)

    // Assignments
    case assignment(Assignment)

    // Function/Procedure
    case functionDeclaration(FunctionDeclaration)
    case procedureDeclaration(ProcedureDeclaration)
    case returnStatement(ReturnStatement)

    // Other
    case expressionStatement(Expression)
    case breakStatement
    case block([Statement])
}

/// Represents an IF statement with optional ELIF and ELSE branches.
public struct IfStatement: Equatable, Codable, Sendable {
    public let condition: Expression
    public let thenBody: [Statement]
    public let elseIfs: [ElseIf]
    public let elseBody: [Statement]?

    public init(condition: Expression, thenBody: [Statement], elseIfs: [ElseIf] = [], elseBody: [Statement]? = nil) {
        self.condition = condition
        self.thenBody = thenBody
        self.elseIfs = elseIfs
        self.elseBody = elseBody
    }

    public struct ElseIf: Equatable, Codable, Sendable {
        public let condition: Expression
        public let body: [Statement]

        public init(condition: Expression, body: [Statement]) {
            self.condition = condition
            self.body = body
        }
    }
}

/// Represents a WHILE statement.
public struct WhileStatement: Equatable, Codable, Sendable {
    public let condition: Expression
    public let body: [Statement]

    public init(condition: Expression, body: [Statement]) {
        self.condition = condition
        self.body = body
    }
}

/// Represents FOR statements (range-based and forEach).
public enum ForStatement: Equatable, Codable, Sendable {
    case range(RangeFor)
    case forEach(ForEachLoop)

    public struct RangeFor: Equatable, Codable, Sendable {
        public let variable: String
        public let start: Expression
        public let end: Expression
        public let step: Expression?
        public let body: [Statement]

        public init(variable: String, start: Expression, end: Expression, step: Expression? = nil, body: [Statement]) {
            self.variable = variable
            self.start = start
            self.end = end
            self.step = step
            self.body = body
        }
    }

    public struct ForEachLoop: Equatable, Codable, Sendable {
        public let variable: String
        public let iterable: Expression
        public let body: [Statement]

        public init(variable: String, iterable: Expression, body: [Statement]) {
            self.variable = variable
            self.iterable = iterable
            self.body = body
        }
    }
}

/// Represents assignment statements.
public enum Assignment: Equatable, Codable, Sendable {
    case variable(String, Expression)
    case arrayElement(ArrayAccess, Expression)

    public struct ArrayAccess: Equatable, Codable, Sendable {
        public let array: Expression
        public let index: Expression

        public init(array: Expression, index: Expression) {
            self.array = array
            self.index = index
        }
    }
}

/// Represents a function declaration.
public struct FunctionDeclaration: Equatable, Codable, Sendable {
    public let name: String
    public let parameters: [Parameter]
    public let returnType: DataType?
    public let localVariables: [VariableDeclaration]
    public let body: [Statement]

    public init(name: String, parameters: [Parameter], returnType: DataType? = nil, localVariables: [VariableDeclaration] = [], body: [Statement]) {
        self.name = name
        self.parameters = parameters
        self.returnType = returnType
        self.localVariables = localVariables
        self.body = body
    }
}

/// Represents a procedure declaration.
public struct ProcedureDeclaration: Equatable, Codable, Sendable {
    public let name: String
    public let parameters: [Parameter]
    public let localVariables: [VariableDeclaration]
    public let body: [Statement]

    public init(name: String, parameters: [Parameter], localVariables: [VariableDeclaration] = [], body: [Statement]) {
        self.name = name
        self.parameters = parameters
        self.localVariables = localVariables
        self.body = body
    }
}

/// Represents a function/procedure parameter.
public struct Parameter: Equatable, Codable, Sendable {
    public let name: String
    public let type: DataType

    public init(name: String, type: DataType) {
        self.name = name
        self.type = type
    }
}

/// Represents a return statement.
public struct ReturnStatement: Equatable, Codable, Sendable {
    public let expression: Expression?

    public init(expression: Expression? = nil) {
        self.expression = expression
    }
}

/// Represents data types in FE pseudo-language.
public indirect enum DataType: Equatable, Codable, Sendable {
    case integer
    case real
    case character
    case string
    case boolean
    case array(DataType)
    case record(String) // record type name

    public init?(tokenType: TokenType) {
        switch tokenType {
        case .integerType:
            self = .integer
        case .realType:
            self = .real
        case .characterType:
            self = .character
        case .stringType:
            self = .string
        case .booleanType:
            self = .boolean
        case .arrayType:
            // Array type requires element type specification, handle separately
            return nil
        case .recordType:
            // Record type requires name specification, handle separately
            return nil
        default:
            return nil
        }
    }
}

/// Represents variable declarations.
public struct VariableDeclaration: Equatable, Codable, Sendable {
    public let name: String
    public let type: DataType
    public let initialValue: Expression?

    public init(name: String, type: DataType, initialValue: Expression? = nil) {
        self.name = name
        self.type = type
        self.initialValue = initialValue
    }
}
