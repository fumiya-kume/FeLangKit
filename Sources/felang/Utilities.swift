import Foundation

/// Read all lines from standard input
func readStdin() -> String {
    var lines: [String] = []
    while let line = readLine() {
        lines.append(line)
    }
    return lines.joined(separator: "\n")
}

/// Read source code from file or inline code
func readSource(file: String?, code: String?) throws -> String {
    if let code = code {
        return code
    }
    if let file = file {
        if file == "-" {
            return readStdin()
        }
        do {
            return try String(contentsOfFile: file, encoding: .utf8)
        } catch {
            throw CLIError.fileNotFound(file)
        }
    }
    throw CLIError.noInput
}

/// CLI error definitions
enum CLIError: Error, CustomStringConvertible {
    case noInput
    case fileNotFound(String)

    var description: String {
        switch self {
        case .noInput:
            return "No input provided. Specify a file or use --code"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        }
    }
}
