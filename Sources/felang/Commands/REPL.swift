import ArgumentParser
import FeLangCore
import FeLangRuntime

struct REPL: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Start interactive REPL session"
    )

    mutating func run() throws {
        print("FeLang REPL v1.0.0")
        print("Type 'exit' or press Ctrl+D to quit")
        print("")

        let interpreter = Interpreter()

        while true {
            print("> ", terminator: "")
            guard let line = readLine() else { break }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "exit" || trimmed == "quit" { break }
            if trimmed.isEmpty { continue }

            do {
                if let result = try interpreter.executeLine(line) {
                    print("=> \(result)")
                }
            } catch {
                print("Error: \(error)")
            }
        }

        print("Goodbye!")
    }
}
