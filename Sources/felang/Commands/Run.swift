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
            FileHandle.standardError.write(Data("Error: \(error)\n".utf8))
            throw ExitCode(3)
        }

        let interpreter = Interpreter()
        do {
            try interpreter.execute(source)
        } catch let error as ParseError {
            FileHandle.standardError.write(Data("Parse error: \(error)\n".utf8))
            throw ExitCode(1)
        } catch let error as RuntimeError {
            FileHandle.standardError.write(Data("Runtime error: \(error)\n".utf8))
            throw ExitCode(2)
        } catch {
            FileHandle.standardError.write(Data("Error: \(error)\n".utf8))
            throw ExitCode(1)
        }
    }
}
