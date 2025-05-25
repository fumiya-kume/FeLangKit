import Foundation

/// Utilities for processing escape sequences in strings and character literals.
/// This provides a centralized implementation to avoid duplication between
/// tokenization and literal processing phases.
public enum StringEscapeUtilities {

    /// Error representing invalid escape sequence with position information
    public struct EscapeSequenceError: Error, Equatable {
        public let message: String
        public let position: Int?
        
        public init(message: String, position: Int? = nil) {
            self.message = message
            self.position = position
        }
    }

    /// Processes escape sequences in string content.
    /// 
    /// This function converts escape sequences like "\n", "\t", "\"", etc. into their
    /// actual character representations. It handles standard C-style escape sequences
    /// and Unicode escape sequences commonly used in programming languages.
    /// 
    /// Supported escape sequences:
    /// - `\n` → newline character
    /// - `\t` → tab character
    /// - `\r` → carriage return
    /// - `\\` → backslash character
    /// - `\"` → double quote character
    /// - `\'` → single quote character
    /// - `\u{XXXX}` → Unicode code point (e.g., \u{1F600} for 😀)
    /// 
    /// - Parameter content: The raw string content containing escape sequences
    /// - Returns: The processed string with escape sequences converted to actual characters
    /// - Throws: EscapeSequenceError if invalid escape sequences are encountered
    /// 
    /// Example:
    /// ```swift
    /// let input = "Hello\\nWorld\\t!"
    /// let output = try StringEscapeUtilities.processEscapeSequences(input)
    /// // output: "Hello\nWorld\t!"
    /// ```
    public static func processEscapeSequences(_ content: String) throws -> String {
        var result = ""
        var index = content.startIndex

        while index < content.endIndex {
            if content[index] == "\\" {
                let (char, nextIndex) = try processEscapeAt(content, index: index)
                result.append(char)
                index = nextIndex
            } else {
                result.append(content[index])
                index = content.index(after: index)
            }
        }

        return result
    }

    /// Processes a single escape sequence at the given index
    /// - Parameters:
    ///   - content: The string content containing the escape sequence
    ///   - index: The index of the backslash character
    /// - Returns: A tuple containing the processed character and the next index to continue from
    /// - Throws: EscapeSequenceError if the escape sequence is invalid
    public static func processEscapeAt(_ content: String, index: String.Index) throws -> (Character, String.Index) {
        guard index < content.endIndex && content[index] == "\\" else {
            let position = content.distance(from: content.startIndex, to: index)
            throw EscapeSequenceError(message: "Expected backslash at position", position: position)
        }
        
        let nextIndex = content.index(after: index)
        guard nextIndex < content.endIndex else {
            let position = content.distance(from: content.startIndex, to: index)
            throw EscapeSequenceError(message: "Incomplete escape sequence at end of string", position: position)
        }
        
        let escapedChar = content[nextIndex]
        let afterEscapeIndex = content.index(after: nextIndex)
        
        switch escapedChar {
        case "n":
            return ("\n", afterEscapeIndex)
        case "t":
            return ("\t", afterEscapeIndex)
        case "r":
            return ("\r", afterEscapeIndex)
        case "\\":
            return ("\\", afterEscapeIndex)
        case "\"":
            return ("\"", afterEscapeIndex)
        case "'":
            return ("'", afterEscapeIndex)
        case "u":
            return try processUnicodeEscape(content, at: index)
        default:
            let position = content.distance(from: content.startIndex, to: index)
            throw EscapeSequenceError(message: "Invalid escape sequence \\\\(escapedChar)", position: position)
        }
    }

    /// Processes a Unicode escape sequence (\u{XXXX})
    /// - Parameters:
    ///   - content: The string content containing the Unicode escape sequence
    ///   - index: The index of the backslash character
    /// - Returns: A tuple containing the Unicode character and the next index to continue from
    /// - Throws: EscapeSequenceError if the Unicode escape sequence is invalid
    public static func processUnicodeEscape(_ content: String, at index: String.Index) throws -> (Character, String.Index) {
        let position = content.distance(from: content.startIndex, to: index)
        
        // We expect: \u{XXXX}
        // index points to '\'
        // nextIndex points to 'u'
        let nextIndex = content.index(after: index)
        guard nextIndex < content.endIndex && content[nextIndex] == "u" else {
            throw EscapeSequenceError(message: "Expected 'u' after backslash in Unicode escape", position: position)
        }
        
        let braceStartIndex = content.index(after: nextIndex)
        guard braceStartIndex < content.endIndex && content[braceStartIndex] == "{" else {
            throw EscapeSequenceError(message: "Expected '{' after \\u in Unicode escape", position: position)
        }
        
        // Find the closing brace
        let hexStartIndex = content.index(after: braceStartIndex)
        var hexEndIndex = hexStartIndex
        
        while hexEndIndex < content.endIndex && content[hexEndIndex] != "}" {
            hexEndIndex = content.index(after: hexEndIndex)
        }
        
        guard hexEndIndex < content.endIndex else {
            throw EscapeSequenceError(message: "Unterminated Unicode escape sequence", position: position)
        }
        
        let hexString = String(content[hexStartIndex..<hexEndIndex])
        
        // Validate hex string length (1-8 characters)
        guard !hexString.isEmpty && hexString.count <= 8 else {
            throw EscapeSequenceError(message: "Unicode escape sequence must have 1-8 hex digits", position: position)
        }
        
        // Validate all characters are hex digits
        guard hexString.allSatisfy({ $0.isHexDigit }) else {
            throw EscapeSequenceError(message: "Invalid hex characters in Unicode escape sequence", position: position)
        }
        
        // Convert to Unicode scalar
        guard let value = UInt32(hexString, radix: 16),
              let scalar = UnicodeScalar(value) else {
            throw EscapeSequenceError(message: "Invalid Unicode code point: \\u{\\(hexString)}", position: position)
        }
        
        let character = Character(scalar)
        let afterBraceIndex = content.index(after: hexEndIndex)
        
        return (character, afterBraceIndex)
    }

    /// Validates that escape sequences in string content are properly formed.
    /// 
    /// This function checks for common escape sequence errors such as:
    /// - Unfinished escape sequences at end of string
    /// - Invalid escape sequence characters
    /// - Malformed Unicode escape sequences
    /// 
    /// - Parameter content: The raw string content to validate
    /// - Returns: An array of validation errors with position information
    /// 
    /// Example:
    /// ```swift
    /// let errors = StringEscapeUtilities.validateEscapeSequencesWithDetails("Hello\\nWorld")
    /// // errors: [] (empty array for valid content)
    /// 
    /// let errors2 = StringEscapeUtilities.validateEscapeSequencesWithDetails("Hello\\")
    /// // errors: [EscapeSequenceError(...)] for unfinished escape
    /// ```
    public static func validateEscapeSequencesWithDetails(_ content: String) -> [(position: Int, error: String)] {
        var errors: [(position: Int, error: String)] = []
        var index = content.startIndex

        while index < content.endIndex {
            if content[index] == "\\" {
                do {
                    let (_, nextIndex) = try processEscapeAt(content, index: index)
                    index = nextIndex
                } catch let error as EscapeSequenceError {
                    let position = error.position ?? content.distance(from: content.startIndex, to: index)
                    errors.append((position: position, error: error.message))
                    // Skip the problematic escape sequence
                    index = content.index(after: index)
                    if index < content.endIndex {
                        index = content.index(after: index)
                    }
                } catch {
                    // Handle any other errors that might be thrown
                    let position = content.distance(from: content.startIndex, to: index)
                    errors.append((position: position, error: "Unknown escape sequence error"))
                    index = content.index(after: index)
                    if index < content.endIndex {
                        index = content.index(after: index)
                    }
                }
            } else {
                index = content.index(after: index)
            }
        }

        return errors
    }

    /// Validates that escape sequences in string content are properly formed.
    /// 
    /// This is a simplified version that returns a boolean for backward compatibility.
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
        let errors = validateEscapeSequencesWithDetails(content)
        return errors.isEmpty
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
            if content[index] == "\\" {
                do {
                    let (_, nextIndex) = try processEscapeAt(content, index: index)
                count += 1
                    index = nextIndex
                } catch {
                    // Skip invalid escape sequences
                    index = content.index(after: index)
                    if index < content.endIndex {
                        index = content.index(after: index)
                    }
                }
            } else {
                index = content.index(after: index)
            }
        }

        return count
    }

    /// Checks if a string contains any escape sequences (fast path detection).
    /// 
    /// This is an optimization method to quickly determine if escape processing is needed.
    /// 
    /// - Parameter content: The string content to check
    /// - Returns: `true` if the string contains escape sequences, `false` otherwise
    public static func containsEscapeSequences(_ content: String) -> Bool {
        return content.contains("\\")
    }
}

extension Character {
    /// Returns true if the character is a valid hexadecimal digit
    fileprivate var isHexDigit: Bool {
        return self.isNumber || ("a"..."f").contains(self) || ("A"..."F").contains(self)
    }
}
