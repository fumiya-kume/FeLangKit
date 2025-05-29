import Foundation

/// A utility for transforming expressions using the visitor pattern.
///
/// `ExpressionTransformer` provides a convenient way to create visitors that transform
/// expressions while maintaining their structure. It handles the recursive traversal
/// automatically and allows you to specify transformation rules for specific node types.
///
/// Example usage:
/// ```swift
/// // Create a transformer that doubles all integer literals
/// let doubler = ExpressionTransformer.create(
///     transformLiteral: { literal in
///         if case .integer(let value) = literal {
///             return .literal(.integer(value * 2))
///         }
///         return .literal(literal)
///     }
/// )
/// 
/// let transformed = doubler.visit(expression)
/// ```
public struct ExpressionTransformer: Sendable {

    /// The underlying visitor that performs the transformation
    private let visitor: ExpressionVisitor<Expression>

    /// Creates a new expression transformer with the given transformation functions.
    /// 
    /// Only specify transformation functions for node types you want to transform.
    /// All other nodes will be traversed recursively with their structure preserved.
    ///
    /// - Parameters:
    ///   - transformLiteral: Optional transformation for literal expressions
    ///   - transformIdentifier: Optional transformation for identifier expressions
    ///   - transformBinary: Optional transformation for binary expressions
    ///   - transformUnary: Optional transformation for unary expressions
    ///   - transformArrayAccess: Optional transformation for array access expressions
    ///   - transformFieldAccess: Optional transformation for field access expressions
    ///   - transformFunctionCall: Optional transformation for function call expressions
    public init(
        transformLiteral: (@Sendable (Literal) -> Expression)? = nil,
        transformIdentifier: (@Sendable (String) -> Expression)? = nil,
        transformBinary: (@Sendable (BinaryOperator, Expression, Expression) -> Expression)? = nil,
        transformUnary: (@Sendable (UnaryOperator, Expression) -> Expression)? = nil,
        transformArrayAccess: (@Sendable (Expression, Expression) -> Expression)? = nil,
        transformFieldAccess: (@Sendable (Expression, String) -> Expression)? = nil,
        transformFunctionCall: (@Sendable (String, [Expression]) -> Expression)? = nil
    ) {
        self.visitor = ExpressionVisitor<Expression>(
            visitLiteral: { literal in
                if let transform = transformLiteral {
                    return transform(literal)
                }
                return .literal(literal)
            },
            visitIdentifier: { identifier in
                if let transform = transformIdentifier {
                    return transform(identifier)
                }
                return .identifier(identifier)
            },
            visitBinary: { binaryOp, left, right in
                // First recursively transform children
                let transformedLeft = ExpressionTransformer(
                    transformLiteral: transformLiteral,
                    transformIdentifier: transformIdentifier,
                    transformBinary: transformBinary,
                    transformUnary: transformUnary,
                    transformArrayAccess: transformArrayAccess,
                    transformFieldAccess: transformFieldAccess,
                    transformFunctionCall: transformFunctionCall
                ).transform(left)

                let transformedRight = ExpressionTransformer(
                    transformLiteral: transformLiteral,
                    transformIdentifier: transformIdentifier,
                    transformBinary: transformBinary,
                    transformUnary: transformUnary,
                    transformArrayAccess: transformArrayAccess,
                    transformFieldAccess: transformFieldAccess,
                    transformFunctionCall: transformFunctionCall
                ).transform(right)

                // Then apply transformation if provided
                if let transform = transformBinary {
                    return transform(binaryOp, transformedLeft, transformedRight)
                }
                return .binary(binaryOp, transformedLeft, transformedRight)
            },
            visitUnary: { unaryOp, operand in
                // First recursively transform child
                let transformedOperand = ExpressionTransformer(
                    transformLiteral: transformLiteral,
                    transformIdentifier: transformIdentifier,
                    transformBinary: transformBinary,
                    transformUnary: transformUnary,
                    transformArrayAccess: transformArrayAccess,
                    transformFieldAccess: transformFieldAccess,
                    transformFunctionCall: transformFunctionCall
                ).transform(operand)

                // Then apply transformation if provided
                if let transform = transformUnary {
                    return transform(unaryOp, transformedOperand)
                }
                return .unary(unaryOp, transformedOperand)
            },
            visitArrayAccess: { array, index in
                // First recursively transform children
                let transformedArray = ExpressionTransformer(
                    transformLiteral: transformLiteral,
                    transformIdentifier: transformIdentifier,
                    transformBinary: transformBinary,
                    transformUnary: transformUnary,
                    transformArrayAccess: transformArrayAccess,
                    transformFieldAccess: transformFieldAccess,
                    transformFunctionCall: transformFunctionCall
                ).transform(array)

                let transformedIndex = ExpressionTransformer(
                    transformLiteral: transformLiteral,
                    transformIdentifier: transformIdentifier,
                    transformBinary: transformBinary,
                    transformUnary: transformUnary,
                    transformArrayAccess: transformArrayAccess,
                    transformFieldAccess: transformFieldAccess,
                    transformFunctionCall: transformFunctionCall
                ).transform(index)

                // Then apply transformation if provided
                if let transform = transformArrayAccess {
                    return transform(transformedArray, transformedIndex)
                }
                return .arrayAccess(transformedArray, transformedIndex)
            },
            visitFieldAccess: { object, field in
                // First recursively transform child
                let transformedObject = ExpressionTransformer(
                    transformLiteral: transformLiteral,
                    transformIdentifier: transformIdentifier,
                    transformBinary: transformBinary,
                    transformUnary: transformUnary,
                    transformArrayAccess: transformArrayAccess,
                    transformFieldAccess: transformFieldAccess,
                    transformFunctionCall: transformFunctionCall
                ).transform(object)

                // Then apply transformation if provided
                if let transform = transformFieldAccess {
                    return transform(transformedObject, field)
                }
                return .fieldAccess(transformedObject, field)
            },
            visitFunctionCall: { function, arguments in
                // First recursively transform arguments
                let transformedArguments = arguments.map { argument in
                    ExpressionTransformer(
                        transformLiteral: transformLiteral,
                        transformIdentifier: transformIdentifier,
                        transformBinary: transformBinary,
                        transformUnary: transformUnary,
                        transformArrayAccess: transformArrayAccess,
                        transformFieldAccess: transformFieldAccess,
                        transformFunctionCall: transformFunctionCall
                    ).transform(argument)
                }

                // Then apply transformation if provided
                if let transform = transformFunctionCall {
                    return transform(function, transformedArguments)
                }
                return .functionCall(function, transformedArguments)
            }
        )
    }

    /// Transforms the given expression using this transformer.
    /// - Parameter expression: The expression to transform
    /// - Returns: The transformed expression
    public func transform(_ expression: Expression) -> Expression {
        return visitor.visit(expression)
    }

    // MARK: - Common Transformers

    /// Creates a transformer that replaces all occurrences of a specific identifier with another expression.
    /// - Parameters:
    ///   - identifier: The identifier name to replace
    ///   - replacement: The expression to replace it with
    /// - Returns: A transformer that performs the replacement
    public static func createIdentifierReplacer(
        identifier: String,
        replacement: Expression
    ) -> ExpressionTransformer {
        return ExpressionTransformer(
            transformIdentifier: { name in
                return name == identifier ? replacement : .identifier(name)
            }
        )
    }

    /// Creates a transformer that applies constant folding to binary arithmetic operations.
    /// - Returns: A transformer that folds constant arithmetic expressions
    public static func createConstantFolder() -> ExpressionTransformer {
        return ExpressionTransformer(
            transformBinary: { binaryOp, left, right in
                guard case .literal(let leftLit) = left,
                      case .literal(let rightLit) = right else {
                    return .binary(binaryOp, left, right)
                }

                switch (binaryOp, leftLit, rightLit) {
                case (.add, .integer(let leftValue), .integer(let rightValue)):
                    return .literal(.integer(leftValue + rightValue))
                case (.subtract, .integer(let leftValue), .integer(let rightValue)):
                    return .literal(.integer(leftValue - rightValue))
                case (.multiply, .integer(let leftValue), .integer(let rightValue)):
                    return .literal(.integer(leftValue * rightValue))
                case (.divide, .integer(let leftValue), .integer(let rightValue)) where rightValue != 0:
                    return .literal(.integer(leftValue / rightValue))
                case (.add, .real(let leftValue), .real(let rightValue)):
                    return .literal(.real(leftValue + rightValue))
                case (.subtract, .real(let leftValue), .real(let rightValue)):
                    return .literal(.real(leftValue - rightValue))
                case (.multiply, .real(let leftValue), .real(let rightValue)):
                    return .literal(.real(leftValue * rightValue))
                case (.divide, .real(let leftValue), .real(let rightValue)) where rightValue != 0:
                    return .literal(.real(leftValue / rightValue))
                default:
                    return .binary(binaryOp, left, right)
                }
            }
        )
    }

    /// Creates a transformer that negates all boolean literals.
    /// - Returns: A transformer that negates boolean values
    public static func createBooleanNegator() -> ExpressionTransformer {
        return ExpressionTransformer(
            transformLiteral: { literal in
                if case .boolean(let value) = literal {
                    return .literal(.boolean(!value))
                }
                return .literal(literal)
            }
        )
    }

    /// Creates a transformer that converts all identifiers to uppercase.
    /// - Returns: A transformer that uppercases identifier names
    public static func createIdentifierUppercaser() -> ExpressionTransformer {
        return ExpressionTransformer(
            transformIdentifier: { identifier in
                return .identifier(identifier.uppercased())
            }
        )
    }

    /// Creates a transformer that applies two transformations in sequence.
    /// - Parameters:
    ///   - first: The first transformer to apply
    ///   - second: The second transformer to apply
    /// - Returns: A transformer that applies both transformations
    public static func createComposite(_ first: ExpressionTransformer, _ second: ExpressionTransformer) -> ExpressionTransformer {
        return ExpressionTransformer(
            transformLiteral: { literal in
                let firstResult = first.transform(.literal(literal))
                return second.transform(firstResult)
            },
            transformIdentifier: { identifier in
                let firstResult = first.transform(.identifier(identifier))
                return second.transform(firstResult)
            },
            transformBinary: { binaryOp, left, right in
                let firstResult = first.transform(.binary(binaryOp, left, right))
                return second.transform(firstResult)
            },
            transformUnary: { unaryOp, operand in
                let firstResult = first.transform(.unary(unaryOp, operand))
                return second.transform(firstResult)
            },
            transformArrayAccess: { array, index in
                let firstResult = first.transform(.arrayAccess(array, index))
                return second.transform(firstResult)
            },
            transformFieldAccess: { object, field in
                let firstResult = first.transform(.fieldAccess(object, field))
                return second.transform(firstResult)
            },
            transformFunctionCall: { function, arguments in
                let firstResult = first.transform(.functionCall(function, arguments))
                return second.transform(firstResult)
            }
        )
    }
}
