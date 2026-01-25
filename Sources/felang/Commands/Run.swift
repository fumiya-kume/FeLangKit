import ArgumentParser
import FeLangCore
import FeLangRuntime
import Foundation

struct Run: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Execute FE pseudo-language source code"
    )

    @Argument(help: "Source file to execute (use '-' for stdin)")
    var file: String?

    @Option(name: .shortAndLong, help: "Source code to execute directly")
    var code: String?

    mutating func run() throws {
        let source: String
        do {
            source = try readSource(file: file, code: code)
        } catch let error as CLIError {
            fputs("Error: \(error)\n", stderr)
            throw ExitCode(3)
        }

        let interpreter = Interpreter()
        do {
            try interpreter.execute(source)
        } catch let error as ParseError {
            fputs("Parse error: \(error)\n", stderr)
            throw ExitCode(1)
        } catch let error as RuntimeError {
            fputs("Runtime error: \(error)\n", stderr)
            throw ExitCode(2)
        } catch {
            fputs("Error: \(error)\n", stderr)
            throw ExitCode(1)
        }
    }
}
