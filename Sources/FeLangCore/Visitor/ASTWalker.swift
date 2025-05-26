import Foundation

/// A utility class that provides automatic recursive traversal of AST nodes.
/// ASTWalker enables deep traversal of Expression and Statement trees,
/// automatically visiting child nodes and collecting results.
@Sendable
public struct ASTWalker {
    
    /// Options for controlling AST traversal behavior.
    public struct TraversalOptions: Sendable {
        /// Whether to traverse in depth-first order (true) or breadth-first order (false).
        public let depthFirst: Bool
        
        /// Maximum depth to traverse (nil for unlimited).
        public let maxDepth: Int?
        
        /// Whether to include the root node in the traversal results.
        public let includeRoot: Bool
        
        /// Creates traversal options with the specified parameters.
        /// - Parameters:
        ///   - depthFirst: Whether to use depth-first traversal (default: true)
        ///   - maxDepth: Maximum depth to traverse (default: nil for unlimited)
        ///   - includeRoot: Whether to include the root node (default: true)
        public init(depthFirst: Bool = true, maxDepth: Int? = nil, includeRoot: Bool = true) {
            self.depthFirst = depthFirst
            self.maxDepth = maxDepth
            self.includeRoot = includeRoot
        }
        
        /// Default traversal options: depth-first, unlimited depth, including root.
        public static let `default` = TraversalOptions()
    }
    
    /// Walks an expression tree and collects all expressions using depth-first traversal.
    /// - Parameters:
    ///   - expression: The root expression to start traversal from
    ///   - options: Traversal options (default: depth-first, unlimited, include root)
    /// - Returns: An array of all expressions encountered during traversal
    public static func walkExpression(_ expression: Expression, options: TraversalOptions = .default) -> [Expression] {
        var visited: [Expression] = []
        var stack: [(Expression, Int)] = [(expression, 0)]
        
        if options.depthFirst {
            // Depth-first traversal using a stack
            while !stack.isEmpty {
                let (current, depth) = stack.removeLast()
                
                // Check depth limit
                if let maxDepth = options.maxDepth, depth > maxDepth {
                    continue
                }
                
                // Add current node if it should be included
                if options.includeRoot || depth > 0 {
                    visited.append(current)
                }
                
                // Add child nodes to stack (in reverse order for correct DFS ordering)
                let children = getExpressionChildren(current)
                for child in children.reversed() {
                    stack.append((child, depth + 1))
                }
            }
        } else {
            // Breadth-first traversal using a queue
            var queue: [(Expression, Int)] = [(expression, 0)]
            
            while !queue.isEmpty {
                let (current, depth) = queue.removeFirst()
                
                // Check depth limit
                if let maxDepth = options.maxDepth, depth > maxDepth {
                    continue
                }
                
                // Add current node if it should be included
                if options.includeRoot || depth > 0 {
                    visited.append(current)
                }
                
                // Add child nodes to queue
                let children = getExpressionChildren(current)
                for child in children {
                    queue.append((child, depth + 1))
                }
            }
        }
        
        return visited
    }
    
    /// Walks a statement tree and collects all statements using depth-first traversal.
    /// - Parameters:
    ///   - statement: The root statement to start traversal from
    ///   - options: Traversal options (default: depth-first, unlimited, include root)
    /// - Returns: An array of all statements encountered during traversal
    public static func walkStatement(_ statement: Statement, options: TraversalOptions = .default) -> [Statement] {
        var visited: [Statement] = []
        var stack: [(Statement, Int)] = [(statement, 0)]
        
        if options.depthFirst {
            // Depth-first traversal using a stack
            while !stack.isEmpty {
                let (current, depth) = stack.removeLast()
                
                // Check depth limit
                if let maxDepth = options.maxDepth, depth > maxDepth {
                    continue
                }
                
                // Add current node if it should be included
                if options.includeRoot || depth > 0 {
                    visited.append(current)
                }
                
                // Add child nodes to stack (in reverse order for correct DFS ordering)
                let children = getStatementChildren(current)
                for child in children.reversed() {
                    stack.append((child, depth + 1))
                }
            }
        } else {
            // Breadth-first traversal using a queue
            var queue: [(Statement, Int)] = [(statement, 0)]
            
            while !queue.isEmpty {
                let (current, depth) = queue.removeFirst()
                
                // Check depth limit
                if let maxDepth = options.maxDepth, depth > maxDepth {
                    continue
                }
                
                // Add current node if it should be included
                if options.includeRoot || depth > 0 {
                    visited.append(current)
                }
                
                // Add child nodes to queue
                let children = getStatementChildren(current)
                for child in children {
                    queue.append((child, depth + 1))
                }
            }
        }
        
        return visited
    }
    
    /// Walks a statement tree and collects all expressions within it.
    /// - Parameters:
    ///   - statement: The root statement to start traversal from
    ///   - options: Traversal options (default: depth-first, unlimited, include root)
    /// - Returns: An array of all expressions found within the statement tree
    public static func walkStatementsForExpressions(_ statement: Statement, options: TraversalOptions = .default) -> [Expression] {
        var expressions: [Expression] = []
        let statements = walkStatement(statement, options: options)
        
        for stmt in statements {
            expressions.append(contentsOf: getExpressionsFromStatement(stmt))
        }
        
        return expressions
    }
    
    /// Recursively applies a visitor to an expression tree and collects all results.
    /// - Parameters:
    ///   - expression: The root expression to visit
    ///   - visitor: The visitor to apply to each expression
    ///   - options: Traversal options (default: depth-first, unlimited, include root)
    /// - Returns: An array of results from visiting each expression
    public static func visitExpressionTree<Result: Sendable>(
        _ expression: Expression,
        with visitor: ExpressionVisitor<Result>,
        options: TraversalOptions = .default
    ) -> [Result] {
        let expressions = walkExpression(expression, options: options)
        return expressions.map { visitor.visit($0) }
    }
    
    /// Recursively applies a visitor to a statement tree and collects all results.
    /// - Parameters:
    ///   - statement: The root statement to visit
    ///   - visitor: The visitor to apply to each statement
    ///   - options: Traversal options (default: depth-first, unlimited, include root)
    /// - Returns: An array of results from visiting each statement
    public static func visitStatementTree<Result: Sendable>(
        _ statement: Statement,
        with visitor: StatementVisitor<Result>,
        options: TraversalOptions = .default
    ) -> [Result] {
        let statements = walkStatement(statement, options: options)
        return statements.map { visitor.visit($0) }
    }
}

// MARK: - Private Helper Methods

extension ASTWalker {
    /// Extracts direct child expressions from an expression.
    private static func getExpressionChildren(_ expression: Expression) -> [Expression] {
        switch expression {
        case .literal:
            return []
        case .identifier:
            return []
        case .binary(_, let left, let right):
            return [left, right]
        case .unary(_, let expr):
            return [expr]
        case .arrayAccess(let array, let index):
            return [array, index]
        case .fieldAccess(let object, _):
            return [object]
        case .functionCall(_, let args):
            return args
        }
    }
    
    /// Extracts direct child statements from a statement.
    private static func getStatementChildren(_ statement: Statement) -> [Statement] {
        switch statement {
        case .ifStatement(let ifStmt):
            var children = ifStmt.thenBody
            for elseIf in ifStmt.elseIfs {
                children.append(contentsOf: elseIf.body)
            }
            if let elseBody = ifStmt.elseBody {
                children.append(contentsOf: elseBody)
            }
            return children
            
        case .whileStatement(let whileStmt):
            return whileStmt.body
            
        case .forStatement(let forStmt):
            switch forStmt {
            case .range(let rangeFor):
                return rangeFor.body
            case .forEach(let forEach):
                return forEach.body
            }
            
        case .assignment:
            return []
            
        case .variableDeclaration:
            return []
            
        case .constantDeclaration:
            return []
            
        case .functionDeclaration(let funcDecl):
            return funcDecl.body
            
        case .procedureDeclaration(let procDecl):
            return procDecl.body
            
        case .returnStatement:
            return []
            
        case .expressionStatement:
            return []
            
        case .breakStatement:
            return []
            
        case .block(let statements):
            return statements
        }
    }
    
    /// Extracts all expressions from a statement.
    private static func getExpressionsFromStatement(_ statement: Statement) -> [Expression] {
        switch statement {
        case .ifStatement(let ifStmt):
            var expressions = [ifStmt.condition]
            for elseIf in ifStmt.elseIfs {
                expressions.append(elseIf.condition)
            }
            return expressions
            
        case .whileStatement(let whileStmt):
            return [whileStmt.condition]
            
        case .forStatement(let forStmt):
            switch forStmt {
            case .range(let rangeFor):
                var expressions = [rangeFor.start, rangeFor.end]
                if let step = rangeFor.step {
                    expressions.append(step)
                }
                return expressions
            case .forEach(let forEach):
                return [forEach.iterable]
            }
            
        case .assignment(let assignment):
            switch assignment {
            case .variable(_, let expr):
                return [expr]
            case .arrayElement(let arrayAccess, let expr):
                return [arrayAccess.array, arrayAccess.index, expr]
            }
            
        case .variableDeclaration(let varDecl):
            return varDecl.initialValue.map { [$0] } ?? []
            
        case .constantDeclaration(let constDecl):
            return [constDecl.initialValue]
            
        case .functionDeclaration:
            return []
            
        case .procedureDeclaration:
            return []
            
        case .returnStatement(let returnStmt):
            return returnStmt.expression.map { [$0] } ?? []
            
        case .expressionStatement(let expr):
            return [expr]
            
        case .breakStatement:
            return []
            
        case .block:
            return []
        }
    }
}