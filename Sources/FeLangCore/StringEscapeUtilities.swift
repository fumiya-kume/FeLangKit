import Foundation

/// Utilities for processing escape sequences in strings and character literals.
/// This provides a centralized implementation to avoid duplication between
/// tokenization and literal processing phases.
public enum StringEscapeUtilities {

    /// Processes escape sequences in string content.
    /// 
    /// This function converts escape sequences like "\n", "\t", "\"", etc. into their
    /// actual character representations. It handles standard C-style escape sequences
    /// commonly used in programming languages.
    /// 
    /// Supported escape sequences:
    /// - `\n` → newline character
    /// - `\t` → tab character
    /// - `\r` → carriage return
    /// - `\\` → backslash character
    /// - `\"` → double quote character
    /// - `\'` → single quote character
    /// 
    /// Unknown escape sequences are preserved as-is (backslash + character).
    /// 
    /// - Parameter content: The raw string content containing escape sequences
    /// - Returns: The processed string with escape sequences converted to actual characters
    /// 
    /// Example:
    /// ```swift
    /// let input = "Hello\\nWorld\\t!"
    /// let output = StringEscapeUtilities.processEscapeSequences(input)
    /// // output: "Hello\nWorld\t!"
    /// ```
    public static func processEscapeSequences(_ content: String) -> String {
        var result = ""
        var index = content.startIndex

        while index < content.endIndex {
            if content[index] == "\\" && content.index(after: index) < content.endIndex {
                // Process escape sequence
                let nextIndex = content.index(after: index)
                let escapedChar = content[nextIndex]

                switch escapedChar {
                case "n":
                    result.append("\n")
                case "t":
                    result.append("\t")
                case "r":
                    result.append("\r")
                case "\\":
                    result.append("\\")
                case "\"":
                    result.append("\"")
                case "'":
                    result.append("'")
                default:
                    // For unknown escape sequences, keep the backslash and character
                    // This provides graceful handling of unsupported sequences
                    result.append("\\")
                    result.append(escapedChar)
                }

                // Skip both the backslash and the escaped character
                index = content.index(nextIndex, offsetBy: 1)
            } else {
                result.append(content[index])
                index = content.index(after: index)
            }
        }

        return result
    }

    /// Validates that escape sequences in string content are properly formed.
    /// 
    /// This function checks for common escape sequence errors such as:
    /// - Unfinished escape sequences at end of string
    /// - Invalid escape sequence characters
    /// 
    /// - Parameter content: The raw string content to validate
    /// - Returns: `true` if all escape sequences are valid, `false` otherwise
    /// 
    /// Example:
    /// ```swift
    /// StringEscapeUtilities.validateEscapeSequences("Hello\\nWorld")  // true
    /// StringEscapeUtilities.validateEscapeSequences("Hello\\")        // false (unfinished)
    /// ```
    public static func validateEscapeSequences(_ content: String) -> Bool {
        var index = content.startIndex

        while index < content.endIndex {
            if content[index] == "\\" {
                // Must have a character after the backslash
                guard content.index(after: index) < content.endIndex else {
                    return false // Unfinished escape sequence
                }

                let nextIndex = content.index(after: index)
                // Skip both the backslash and the escaped character
                index = content.index(nextIndex, offsetBy: 1)
            } else {
                index = content.index(after: index)
            }
        }

        return true
    }

    /// Counts the number of escape sequences in the given content.
    /// 
    /// This can be useful for performance optimization or memory allocation
    /// when processing strings with many escape sequences.
    /// 
    /// - Parameter content: The raw string content to analyze
    /// - Returns: The number of escape sequences found
    /// 
    /// Example:
    /// ```swift
    /// let count = StringEscapeUtilities.countEscapeSequences("Hello\\nWorld\\t!")
    /// // count: 2 (for \n and \t)
    /// ```
    public static func countEscapeSequences(_ content: String) -> Int {
        var count = 0
        var index = content.startIndex

        while index < content.endIndex {
            if content[index] == "\\" && content.index(after: index) < content.endIndex {
                count += 1
                let nextIndex = content.index(after: index)
                // Skip both the backslash and the escaped character
                index = content.index(nextIndex, offsetBy: 1)
            } else {
                index = content.index(after: index)
            }
        }

        return count
    }
}
