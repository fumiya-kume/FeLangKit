import Atomics
import Dispatch
import Foundation

struct CLITestHelper {
    /// Path to the built CLI binary
    static var binaryPath: String {
        // Use #filePath to get the source file path at compile time
        let sourceFile = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceFile
            .deletingLastPathComponent()  // FeLangE2ETests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // project root
        return projectRoot.appendingPathComponent(".build/debug/felang").path
    }

    /// Cache for binary verification to avoid redundant file system checks (thread-safe)
    private static let binaryVerified = ManagedAtomic<Bool>(false)

    struct CLIResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }

    /// Run the CLI binary with arguments and optional stdin
    /// - Parameters:
    ///   - arguments: Command line arguments
    ///   - stdin: Optional stdin input
    ///   - timeout: Timeout in seconds (default: 5 seconds)
    /// - Returns: CLIResult with exit code and output
    static func run(
        arguments: [String] = [],
        stdin: String? = nil,
        timeout: TimeInterval = 5.0
    ) throws -> CLIResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        if let stdin = stdin, let stdinData = stdin.data(using: .utf8) {
            let stdinPipe = Pipe()
            stdinPipe.fileHandleForWriting.write(stdinData)
            stdinPipe.fileHandleForWriting.closeFile()
            process.standardInput = stdinPipe
        }

        try process.run()

        // Use blocking wait with timeout instead of polling
        var timedOut = false
        let timeoutWorkItem = DispatchWorkItem {
            if process.isRunning {
                timedOut = true
                process.terminate()
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)

        process.waitUntilExit()
        timeoutWorkItem.cancel()

        if timedOut {
            // Give it a moment to terminate if needed
            if process.isRunning {
                process.interrupt()
            }
            return CLIResult(
                exitCode: -1,
                stdout: "",
                stderr: "Process timed out after \(timeout) seconds"
            )
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return CLIResult(
            exitCode: process.terminationStatus,
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? ""
        )
    }

    /// Verify the CLI binary exists (should be built by swift test automatically)
    static func ensureBinaryBuilt() throws {
        // Use cached result to avoid redundant file system checks (atomic read)
        guard !binaryVerified.load(ordering: .acquiring) else { return }
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            throw CLITestError.binaryNotFound(binaryPath)
        }
        binaryVerified.store(true, ordering: .releasing)
    }
}

enum CLITestError: Error, CustomStringConvertible {
    case binaryNotFound(String)

    var description: String {
        switch self {
        case .binaryNotFound(let path):
            return "CLI binary not found at \(path). Run 'swift build' first."
        }
    }
}
