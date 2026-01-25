import FeLangCore
import FeLangRuntime
import Foundation

/// Helper for running FeLang code in-process without spawning CLI processes.
/// This provides significant performance improvement over CLITestHelper for tests
/// that don't need to test CLI-specific functionality.
struct InProcessTestHelper {
    /// Global lock to prevent concurrent Interpreter execution which causes SIGBUS crashes.
    /// This ensures thread-safety when multiple test suites run in parallel.
    private static let executionLock = NSLock()

    /// Result of executing FeLang code in-process.
    struct ExecutionResult {
        let output: String
        let succeeded: Bool
        let error: Error?
    }

    /// Execute FeLang code and return the result.
    /// - Parameter code: The FeLang source code to execute
    /// - Returns: ExecutionResult containing output, success status, and any error
    static func execute(_ code: String) -> ExecutionResult {
        executionLock.lock()
        defer { executionLock.unlock() }

        let (interpreter, getOutput) = Interpreter.withOutputCapture()

        do {
            try interpreter.execute(code)
            return ExecutionResult(output: getOutput(), succeeded: true, error: nil)
        } catch {
            return ExecutionResult(output: getOutput(), succeeded: false, error: error)
        }
    }

    /// Execute FeLang code and return output, throwing on failure.
    /// - Parameter code: The FeLang source code to execute
    /// - Returns: The captured output from the execution
    /// - Throws: The execution error if the code fails
    static func run(_ code: String) throws -> String {
        let result = execute(code)
        guard result.succeeded else {
            throw result.error ?? InProcessError.executionFailed
        }
        return result.output
    }
}

/// Errors that can occur during in-process execution.
enum InProcessError: Error {
    case executionFailed
}
