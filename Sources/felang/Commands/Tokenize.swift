import ArgumentParser
import FeLangCore
import Foundation

struct Tokenize: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Tokenize source code and display tokens"
    )

    @Argument(help: "Source file to tokenize")
    var file: String?

    @Option(name: .shortAndLong, help: "Source code to tokenize directly")
    var code: String?

    mutating func run() throws {
        let source: String
        do {
            source = try readSource(file: file, code: code)
        } catch let error as CLIError {
            fputs("Error: \(error)\n", stderr)
            throw ExitCode(3)
        }

        do {
            let tokens = try ParsingTokenizer.tokenize(source)

            for token in tokens {
                print("\(token.type)\t\(token.position.line):\(token.position.column)\t\"\(token.lexeme)\"")
            }
        } catch {
            fputs("Tokenize error: \(error)\n", stderr)
            throw ExitCode(1)
        }
    }
}
