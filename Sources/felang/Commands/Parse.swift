import ArgumentParser
import FeLangCore
import Foundation

struct Parse: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Parse source code and display AST"
    )

    @Argument(help: "Source file to parse")
    var file: String?

    @Option(name: .shortAndLong, help: "Source code to parse directly")
    var code: String?

    @Flag(name: .long, help: "Pretty-print back to FE source code")
    var pretty: Bool = false

    mutating func run() throws {
        let source: String
        do {
            source = try readSource(file: file, code: code)
        } catch let error as CLIError {
            fputs("Error: \(error)\n", stderr)
            throw ExitCode(3)
        }

        do {
            let parser = Parser()
            let statements = try parser.parse(source)

            if pretty {
                let printer = PrettyPrinter()
                for statement in statements {
                    print(printer.print(statement))
                }
            } else {
                for statement in statements {
                    print(statement)
                }
            }
        } catch {
            fputs("Parse error: \(error)\n", stderr)
            throw ExitCode(1)
        }
    }
}
