import Foundation
import FeLangCore

/// Main interpreter for executing FE programs.
public final class Interpreter: @unchecked Sendable {
    /// The execution environment
    private let environment: Environment

    /// The statement executor
    private let executor: StatementExecutor

    /// Standard library functions
    private let standardLibrary: StandardLibrary

    /// Custom function bindings
    private var customFunctions: [String: @Sendable ([RuntimeValue]) throws -> RuntimeValue] = [:]

    // MARK: - Initialization

    public init(
        standardLibrary: StandardLibrary = StandardLibrary()
    ) {
        self.environment = Environment()
        self.standardLibrary = standardLibrary
        self.executor = StatementExecutor(environment: environment)

        // Register standard library functions
        registerStandardLibrary()

        executor.setExternalFunctionResolver { [weak self] name, args in
            guard let self = self else {
                throw RuntimeError.generic(message: "Interpreter deallocated")
            }
            if let function = self.customFunctions[name] {
                return try function(args)
            }
            throw RuntimeError.undefinedFunction(name: name)
        }
    }

    private func registerStandardLibrary() {
        for (name, function) in standardLibrary.functions {
            customFunctions[name] = function
        }
    }

    // MARK: - Program Execution

    /// Executes a parsed program (list of statements).
    public func run(_ statements: [Statement]) throws {
        _ = try executor.execute(statements)
    }

    /// Parses and executes source code.
    public func execute(_ source: String) throws {
        let parser = Parser()
        let statements = try parser.parse(source)
        try run(statements)
    }

    /// Evaluates an expression and returns its value.
    public func evaluate(_ expression: FeLangCore.Expression) throws -> RuntimeValue {
        let evaluator = ExpressionEvaluator(
            environment: environment,
            callFunction: { [weak self] name, args in
                guard let self = self else {
                    throw RuntimeError.generic(message: "Interpreter deallocated")
                }
                return try self.callFunction(name, arguments: args)
            },
            callMethod: { [weak self] receiver, methodName, args in
                guard let self = self else {
                    throw RuntimeError.generic(message: "Interpreter deallocated")
                }
                let result = try self.executor.callMethod(receiver, methodName: methodName, arguments: args)
                return (result.returnValue, result.modifiedInstance)
            }
        )
        return try evaluator.evaluate(expression)
    }

    // MARK: - Function Management

    /// Registers a custom function.
    public func registerFunction(
        _ name: String,
        _ function: @escaping @Sendable ([RuntimeValue]) throws -> RuntimeValue
    ) {
        customFunctions[name] = function
    }

    /// Calls a function by name with arguments.
    public func callFunction(_ name: String, arguments: [RuntimeValue]) throws -> RuntimeValue {
        // Check custom/standard library functions first
        if let function = customFunctions[name] {
            return try function(arguments)
        }

        // Then check user-defined functions in the environment
        return try executor.callFunction(name, arguments: arguments)
    }

    // MARK: - Variable Management

    /// Defines a variable in the global scope.
    public func defineVariable(_ name: String, value: RuntimeValue) {
        environment.define(name, value: value)
    }

    /// Gets a variable value.
    public func getVariable(_ name: String) throws -> RuntimeValue {
        try environment.get(name)
    }

    /// Checks if a variable exists.
    public func hasVariable(_ name: String) -> Bool {
        environment.exists(name)
    }

    // MARK: - REPL Support

    /// Executes a single line of code for REPL use.
    public func executeLine(_ line: String) throws -> RuntimeValue? {
        let parser = Parser()

        // Try to parse as expression first
        do {
            let tokens = try ParsingTokenizer.tokenize(line)
            let exprParser = ExpressionParser()
            let expression = try exprParser.parseExpression(from: tokens)
            return try evaluate(expression)
        } catch {
            // If expression parsing fails, try as statements
            let statements = try parser.parse(line)
            _ = try executor.execute(statements)
            return nil
        }
    }
}

// MARK: - Convenience Extensions

extension Interpreter {
    /// Creates an interpreter with custom I/O handlers.
    public static func withCustomIO(
        printHandler: @escaping @Sendable (String) -> Void,
        inputHandler: @escaping @Sendable () -> String?
    ) -> Interpreter {
        let stdlib = StandardLibrary(
            printHandler: printHandler,
            inputHandler: inputHandler
        )
        return Interpreter(standardLibrary: stdlib)
    }

    /// Creates an interpreter that captures output.
    ///
    /// - Note: The returned closures are designed for single-threaded use where
    ///   `printHandler` is called during execution and `getOutput` is called after
    ///   execution completes. They should not be called concurrently.
    public static func withOutputCapture() -> (interpreter: Interpreter, getOutput: @Sendable () -> String) {
        // OutputBuffer is marked @unchecked Sendable because the closures need to be Sendable,
        // but the buffer is only accessed sequentially (append during execution, get after).
        // NSLock was removed to avoid taking and releasing a lock on every print call, which
        // would add unnecessary synchronization overhead in the common single-threaded case.
        //
        // Callers MUST ensure that all accesses to OutputBuffer are sequential (no concurrent
        // calls to the returned printHandler and getOutput). Violating this assumption can
        // lead to data races and undefined behavior.
        final class OutputBuffer: @unchecked Sendable {
            private var outputParts: [String] = []

            func append(_ text: String) {
                outputParts.append(text)
            }

            func get() -> String {
                outputParts.joined()
            }
        }

        let buffer = OutputBuffer()

        let interpreter = withCustomIO(
            printHandler: { text in
                buffer.append(text)
            },
            inputHandler: { nil }
        )

        return (interpreter, { buffer.get() })
    }
}
