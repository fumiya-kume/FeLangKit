import Foundation

/// A pretty printer that converts AST nodes back to canonical FE pseudo-language source code.
public struct PrettyPrinter {

    /// Configuration options for formatting output.
    public struct Configuration {
        /// Number of spaces or tabs for each indentation level.
        public var indentSize: Int

        /// Whether to use spaces (true) or tabs (false) for indentation.
        public var useSpaces: Bool

        /// Maximum line length before wrapping. Set to 0 to disable wrapping.
        public var maxLineLength: Int

        /// Whether to enable line wrapping based on maxLineLength.
        public var enableWrapping: Bool

        public init(indentSize: Int = 4, useSpaces: Bool = true, maxLineLength: Int = 80, enableWrapping: Bool = false) {
            self.indentSize = indentSize
            self.useSpaces = useSpaces
            self.maxLineLength = maxLineLength
            self.enableWrapping = enableWrapping
        }
    }

    private let config: Configuration

    /// Creates a new PrettyPrinter with the specified configuration.
    public init(configuration: Configuration = Configuration()) {
        self.config = configuration
    }

    // MARK: - Line Wrapping Helpers

    /// Checks if a line exceeds the maximum length.
    private func shouldWrap(_ line: String, currentIndent: Int) -> Bool {
        guard config.enableWrapping && config.maxLineLength > 0 else { return false }
        let indentLength = makeIndent(currentIndent).count
        return indentLength + line.count > config.maxLineLength
    }

    /// Wraps a list of items with proper indentation.
    private func wrapItems(_ items: [String], separator: String, indent: Int, prefix: String, suffix: String) -> String {
        let singleLine = prefix + items.joined(separator: separator) + suffix

        if !shouldWrap(singleLine, currentIndent: indent) {
            return singleLine
        }

        // Multi-line format
        let itemIndent = makeIndent(indent + 1)
        var result = prefix + "\n"
        for (index, item) in items.enumerated() {
            // Handle multi-line items: preserve relative indentation by removing only common indent
            let lines = item.split(separator: "\n", omittingEmptySubsequences: false)

            // Calculate minimum common indentation across non-empty lines
            let commonIndent = lines
                .filter { !$0.isEmpty }
                .map { line -> Int in
                    var count = 0
                    for char in line {
                        if char == " " {
                            count += 1
                        } else if char == "\t" {
                            count += config.indentSize
                        } else {
                            break
                        }
                    }
                    return count
                }
                .min() ?? 0

            for (lineIndex, line) in lines.enumerated() {
                if lineIndex > 0 {
                    result += "\n"
                }
                let lineStr = String(line)
                // Remove only the common indentation, preserving relative differences
                var charsToRemove = 0
                var removedIndent = 0
                for char in lineStr {
                    if removedIndent >= commonIndent { break }
                    if char == " " {
                        removedIndent += 1
                        charsToRemove += 1
                    } else if char == "\t" {
                        removedIndent += config.indentSize
                        charsToRemove += 1
                    } else {
                        break
                    }
                }
                let trimmedLine = String(lineStr.dropFirst(charsToRemove))
                result += itemIndent + trimmedLine
            }
            if index < items.count - 1 {
                result += separator.trimmingCharacters(in: .whitespaces)
            }
            result += "\n"
        }
        result += makeIndent(indent) + suffix
        return result
    }

    // MARK: - Public API

    /// Converts an expression to its string representation.
    public func print(_ expression: Expression) -> String {
        return printExpression(expression, indent: 0)
    }

    /// Converts an expression to its string representation with optional indentation for wrapping.
    public func print(_ expression: Expression, indent: Int) -> String {
        return printExpression(expression, indent: indent)
    }

    /// Converts a statement to its string representation with optional indentation.
    public func print(_ statement: Statement, indent: Int = 0) -> String {
        return printStatement(statement, indent: indent)
    }

    /// Converts an array of statements to their string representation.
    public func print(_ statements: [Statement]) -> String {
        return statements.map { printStatement($0, indent: 0) }.joined(separator: "\n")
    }

    // MARK: - Expression Printing

    private func printExpression(_ expression: Expression, indent: Int = 0) -> String {
        switch expression {
        case .literal(let literal):
            return printLiteral(literal)

        case .identifier(let name):
            return name

        case .binary(let binaryOp, let left, let right):
            return printBinaryExpression(binaryOp, left, right, indent: indent)

        case .unary(let unaryOp, let expr):
            return printUnaryExpression(unaryOp, expr, indent: indent)

        case .arrayAccess(let array, let index):
            return "\(printExpression(array, indent: indent))[\(printExpression(index, indent: indent))]"

        case .fieldAccess(let object, let field):
            return "\(printExpression(object, indent: indent)).\(field)"

        case .functionCall(let name, let args):
            return printFunctionCall(name: name, args: args, indent: indent)

        case .methodCall(let receiver, let method, let args):
            return printMethodCall(receiver: receiver, method: method, args: args, indent: indent)

        case .arrayLiteral(let elements):
            return printArrayLiteral(elements: elements, indent: indent)
        }
    }

    /// Prints a function call with optional line wrapping.
    private func printFunctionCall(name: String, args: [Expression], indent: Int) -> String {
        if args.isEmpty {
            return "\(name)()"
        }

        let argStrings = args.map { printExpression($0, indent: indent + 1) }
        let singleLine = "\(name)(\(argStrings.joined(separator: ", ")))"

        if !shouldWrap(singleLine, currentIndent: indent) {
            return singleLine
        }

        // Multi-line format with wrapping
        return wrapItems(argStrings, separator: ", ", indent: indent, prefix: "\(name)(", suffix: ")")
    }

    /// Prints a method call with optional line wrapping.
    private func printMethodCall(receiver: Expression, method: String, args: [Expression], indent: Int) -> String {
        let receiverStr = printExpression(receiver, indent: indent)
        if args.isEmpty {
            return "\(receiverStr).\(method)()"
        }

        let argStrings = args.map { printExpression($0, indent: indent + 1) }
        let singleLine = "\(receiverStr).\(method)(\(argStrings.joined(separator: ", ")))"

        if !shouldWrap(singleLine, currentIndent: indent) {
            return singleLine
        }

        // Multi-line format with wrapping
        return wrapItems(argStrings, separator: ", ", indent: indent, prefix: "\(receiverStr).\(method)(", suffix: ")")
    }

    /// Prints an array literal with optional line wrapping.
    private func printArrayLiteral(elements: [Expression], indent: Int) -> String {
        if elements.isEmpty {
            return "[]"
        }

        let elementStrings = elements.map { printExpression($0, indent: indent + 1) }
        let singleLine = "[\(elementStrings.joined(separator: ", "))]"

        if !shouldWrap(singleLine, currentIndent: indent) {
            return singleLine
        }

        // Multi-line format with wrapping
        return wrapItems(elementStrings, separator: ", ", indent: indent, prefix: "[", suffix: "]")
    }

    private func printLiteral(_ literal: Literal) -> String {
        switch literal {
        case .integer(let value):
            return String(value)

        case .real(let value):
            return String(value)

        case .string(let value):
            // Escape special characters and wrap in quotes
            let escaped = value.map { escapeCharacter($0) }.joined()
            return "\"\(escaped)\""

        case .character(let value):
            // Escape special characters and wrap in single quotes
            let escaped = escapeCharacter(value)
            return "'\(escaped)'"

        case .boolean(let value):
            return value ? "true" : "false"

        case .undefined:
            return "未定義"
        }
    }

    private func printBinaryExpression(
        _ binaryOp: BinaryOperator,
        _ left: Expression,
        _ right: Expression,
        indent: Int = 0
    ) -> String {
        let leftStr = printExpressionWithParentheses(left, parentPrecedence: binaryOp.precedence, isLeft: true, indent: indent)
        let rightStr = printExpressionWithParentheses(right, parentPrecedence: binaryOp.precedence, isLeft: false, indent: indent)
        let singleLine = "\(leftStr) \(binaryOp.rawValue) \(rightStr)"

        // Check if we should wrap the binary expression
        if shouldWrap(singleLine, currentIndent: indent) {
            // Wrap at the operator
            let innerIndent = makeIndent(indent + 1)
            return "\(leftStr)\n\(innerIndent)\(binaryOp.rawValue) \(rightStr)"
        }

        return singleLine
    }

    private func printUnaryExpression(_ unaryOp: UnaryOperator, _ expr: Expression, indent: Int = 0) -> String {
        let exprStr = printExpressionWithParentheses(expr, parentPrecedence: unaryOp.precedence, isLeft: false, indent: indent)
        return "\(unaryOp.rawValue)\(exprStr)"
    }

    private func printExpressionWithParentheses(
        _ expr: Expression,
        parentPrecedence: Int,
        isLeft: Bool,
        indent: Int = 0
    ) -> String {
        let needsParentheses: Bool

        switch expr {
        case .binary(let binaryOp, _, _):
            // Add parentheses if this operator has lower precedence than parent
            // or if it has equal precedence and is right-associative on the right side
            needsParentheses = binaryOp.precedence < parentPrecedence ||
                              (binaryOp.precedence == parentPrecedence && !isLeft && !binaryOp.isLeftAssociative)

        case .unary(let unaryOp, _):
            // Unary operators have high precedence, rarely need parentheses
            needsParentheses = unaryOp.precedence < parentPrecedence

        default:
            needsParentheses = false
        }

        let exprStr = printExpression(expr, indent: indent)
        return needsParentheses ? "(\(exprStr))" : exprStr
    }

    // MARK: - Statement Printing

    private func printStatement(_ statement: Statement, indent: Int) -> String {
        let indentStr = makeIndent(indent)

        switch statement {
        case .ifStatement(let ifStmt):
            return printIfStatement(ifStmt, indent: indent)

        case .whileStatement(let whileStmt):
            return printWhileStatement(whileStmt, indent: indent)

        case .doWhileStatement(let doWhileStmt):
            return printDoWhileStatement(doWhileStmt, indent: indent)

        case .forStatement(let forStmt):
            return printForStatement(forStmt, indent: indent)

        case .assignment(let assignment):
            return indentStr + printAssignment(assignment)

        case .variableDeclaration(let varDecl):
            return indentStr + printVariableDeclaration(varDecl)

        case .constantDeclaration(let constDecl):
            return indentStr + printConstantDeclaration(constDecl)

        case .functionDeclaration(let funcDecl):
            return printFunctionDeclaration(funcDecl, indent: indent)

        case .procedureDeclaration(let procDecl):
            return printProcedureDeclaration(procDecl, indent: indent)

        case .returnStatement(let returnStmt):
            return indentStr + printReturnStatement(returnStmt)

        case .expressionStatement(let expr):
            return indentStr + printExpression(expr, indent: indent)

        case .breakStatement:
            return indentStr + "break"

        case .continueStatement:
            return indentStr + "continue"

        case .block(let statements):
            return printStatements(statements, indent: indent)

        case .recordDeclaration(let recordDecl):
            return printRecordDeclaration(recordDecl, indent: indent)

        case .classDeclaration(let classDecl):
            return printClassDeclaration(classDecl, indent: indent)
        }
    }

    private func printIfStatement(_ ifStmt: IfStatement, indent: Int) -> String {
        let indentStr = makeIndent(indent)
        var result = "\(indentStr)if \(printExpression(ifStmt.condition)) then"

        let thenBodyStr = printStatements(ifStmt.thenBody, indent: indent + 1)
        if !thenBodyStr.isEmpty {
            result += "\n\(thenBodyStr)"
        }

        for elseIf in ifStmt.elseIfs {
            result += "\n\(indentStr)elif \(printExpression(elseIf.condition)) then"
            let elseIfBodyStr = printStatements(elseIf.body, indent: indent + 1)
            if !elseIfBodyStr.isEmpty {
                result += "\n\(elseIfBodyStr)"
            }
        }

        if let elseBody = ifStmt.elseBody {
            result += "\n\(indentStr)else"
            let elseBodyStr = printStatements(elseBody, indent: indent + 1)
            if !elseBodyStr.isEmpty {
                result += "\n\(elseBodyStr)"
            }
        }

        result += "\n\(indentStr)endif"
        return result
    }

    private func printWhileStatement(_ whileStmt: WhileStatement, indent: Int) -> String {
        let indentStr = makeIndent(indent)
        var result = "\(indentStr)while \(printExpression(whileStmt.condition)) do\n"
        result += printStatements(whileStmt.body, indent: indent + 1)
        result += "\n\(indentStr)endwhile"
        return result
    }

    private func printDoWhileStatement(_ doWhileStmt: DoWhileStatement, indent: Int) -> String {
        let indentStr = makeIndent(indent)
        var result = "\(indentStr)do\n"
        result += printStatements(doWhileStmt.body, indent: indent + 1)
        result += "\n\(indentStr)while (\(printExpression(doWhileStmt.condition)))"
        return result
    }

    private func printForStatement(_ forStmt: ForStatement, indent: Int) -> String {
        let indentStr = makeIndent(indent)

        switch forStmt {
        case .range(let rangeFor):
            var result = "\(indentStr)for \(rangeFor.variable) = \(printExpression(rangeFor.start)) to \(printExpression(rangeFor.end))"
            if let step = rangeFor.step {
                result += " step \(printExpression(step))"
            }
            result += " do\n"
            result += printStatements(rangeFor.body, indent: indent + 1)
            result += "\n\(indentStr)endfor"
            return result

        case .forEach(let forEach):
            var result = "\(indentStr)for \(forEach.variable) in \(printExpression(forEach.iterable)) do\n"
            result += printStatements(forEach.body, indent: indent + 1)
            result += "\n\(indentStr)endfor"
            return result
        }
    }

    private func printAssignment(_ assignment: Assignment) -> String {
        switch assignment {
        case .variable(let name, let expr):
            return "\(name) ← \(printExpression(expr))"

        case .arrayElement(let arrayAccess, let expr):
            return "\(printExpression(arrayAccess.array))[\(printExpression(arrayAccess.index))] ← \(printExpression(expr))"

        case .fieldAccess(let fieldAccess, let expr):
            return "\(printExpression(fieldAccess.object)).\(fieldAccess.field) ← \(printExpression(expr))"
        }
    }

    private func printVariableDeclaration(_ varDecl: VariableDeclaration) -> String {
        var result = "変数 \(varDecl.name): \(printDataType(varDecl.type))"
        if let initialValue = varDecl.initialValue {
            result += " ← \(printExpression(initialValue))"
        }
        return result
    }

    private func printConstantDeclaration(_ constDecl: ConstantDeclaration) -> String {
        return "定数 \(constDecl.name): \(printDataType(constDecl.type)) ← \(printExpression(constDecl.initialValue))"
    }

    private func printFunctionDeclaration(_ funcDecl: FunctionDeclaration, indent: Int) -> String {
        return printCallableDeclaration(
            name: funcDecl.name,
            parameters: funcDecl.parameters,
            returnType: funcDecl.returnType,
            localVariables: funcDecl.localVariables,
            body: funcDecl.body,
            indent: indent,
            keyword: "function",
            endKeyword: "endfunction"
        )
    }

    private func printProcedureDeclaration(_ procDecl: ProcedureDeclaration, indent: Int) -> String {
        return printCallableDeclaration(
            name: procDecl.name,
            parameters: procDecl.parameters,
            returnType: nil,
            localVariables: procDecl.localVariables,
            body: procDecl.body,
            indent: indent,
            keyword: "procedure",
            endKeyword: "endprocedure"
        )
    }

    private func printReturnStatement(_ returnStmt: ReturnStatement) -> String {
        if let expr = returnStmt.expression {
            return "return \(printExpression(expr))"
        } else {
            return "return"
        }
    }

    private func printDataType(_ dataType: DataType) -> String {
        switch dataType {
        case .integer:
            return "整数型"
        case .real:
            return "実数型"
        case .character:
            return "文字型"
        case .string:
            return "文字列型"
        case .boolean:
            return "論理型"
        case .array(let elementType):
            return "配列[\(printDataType(elementType))]"
        case .record(let name):
            return "レコード \(name)"
        }
    }

    private func printStatements(_ statements: [Statement], indent: Int) -> String {
        if statements.isEmpty {
            return ""
        }
        return statements.map { printStatement($0, indent: indent) }.joined(separator: "\n")
    }

    private func printRecordDeclaration(_ recordDecl: RecordDeclaration, indent: Int) -> String {
        let indentStr = makeIndent(indent)
        var result = "\(indentStr)record \(recordDecl.name)"

        let hasContent = appendContentLines(recordDecl.fields, to: &result, indent: indent + 1) {
            "\($0.name): \(printDataType($0.type))"
        }

        let newlineBeforeEnd = hasContent ? "" : "\n"
        result += "\(newlineBeforeEnd)\(indentStr)endrecord"
        return result
    }

    private func printClassDeclaration(_ classDecl: ClassDeclaration, indent: Int) -> String {
        let indentStr = makeIndent(indent)
        var result = "\(indentStr)class \(classDecl.name)"

        var hasContent = appendContentLines(classDecl.members, to: &result, indent: indent + 1) {
            "\($0.name): \(printDataType($0.type))"
        }

        if let constructor = classDecl.constructor {
            if !hasContent {
                result += "\n"
                hasContent = true
            }
            let params = constructor.parameters.map { "\($0.name): \(printDataType($0.type))" }.joined(separator: ", ")
            result += makeIndent(indent + 1) + "\(classDecl.name)(\(params))\n"
            result += printStatements(constructor.body, indent: indent + 2) + "\n"
        }

        let newlineBeforeEnd = hasContent ? "" : "\n"
        result += "\(newlineBeforeEnd)\(indentStr)endclass"
        return result
    }

    // MARK: - Utility Methods

    /// Escapes a character for output in string or character literals.
    private func escapeCharacter(_ char: Character) -> String {
        switch char {
        case "\\": return "\\\\"
        case "\"": return "\\\""
        case "'": return "\\'"
        case "\n": return "\\n"
        case "\t": return "\\t"
        case "\r": return "\\r"
        default: return String(char)
        }
    }

    /// Appends formatted content lines to a result string, tracking whether content was added.
    /// Returns true if any content was added, false otherwise.
    @discardableResult
    private func appendContentLines<T>(
        _ items: [T],
        to result: inout String,
        indent: Int,
        formatItem: (T) -> String
    ) -> Bool {
        guard !items.isEmpty else { return false }
        result += "\n"
        for item in items {
            result += makeIndent(indent) + formatItem(item) + "\n"
        }
        return true
    }

    // Prints a callable declaration (function or procedure) with shared formatting logic.
    // swiftlint:disable:next function_parameter_count
    private func printCallableDeclaration(
        name: String,
        parameters: [Parameter],
        returnType: DataType?,
        localVariables: [VariableDeclaration],
        body: [Statement],
        indent: Int,
        keyword: String,
        endKeyword: String
    ) -> String {
        let indentStr = makeIndent(indent)
        let params = parameters.map { "\($0.name): \(printDataType($0.type))" }.joined(separator: ", ")

        var result = "\(indentStr)\(keyword) \(name)(\(params))"
        if let returnType = returnType {
            result += ": \(printDataType(returnType))"
        }

        var hasContent = appendContentLines(localVariables, to: &result, indent: indent + 1) {
            printVariableDeclaration($0)
        }

        let bodyStr = printStatements(body, indent: indent + 1)
        if !bodyStr.isEmpty {
            if !hasContent {
                result += "\n"
                hasContent = true
            }
            result += bodyStr + "\n"
        }

        let newlineBeforeEnd = hasContent ? "" : "\n"
        result += "\(newlineBeforeEnd)\(indentStr)\(endKeyword)"
        return result
    }

    private func makeIndent(_ level: Int) -> String {
        let indentChar = config.useSpaces ? " " : "\t"
        let indentUnit = config.useSpaces ? String(repeating: indentChar, count: config.indentSize) : indentChar
        return String(repeating: indentUnit, count: level)
    }
}
