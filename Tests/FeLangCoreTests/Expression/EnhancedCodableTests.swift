import Testing
@testable import FeLangCore
import Foundation

/// Tests for Phase 2 Enhanced Codable Implementations
/// Validates improvements made for GitHub issue #40
@Suite("Enhanced Codable Implementation Tests")
struct EnhancedCodableTests {

    // MARK: - Enhanced Error Message Tests

    @Test("Enhanced Error Messages - Empty Object")
    func testEnhancedErrorMessageEmptyObject() throws {
        let decoder = JSONDecoder()
        let emptyObjectData = Data("{}".utf8)

        do {
            _ = try decoder.decode(Literal.self, from: emptyObjectData)
            #expect(Bool(false), "Should have thrown an error for empty object")
        } catch let error as DecodingError {
            if case .dataCorrupted(let context) = error {
                #expect(context.debugDescription.contains("Empty literal object"),
                       "Error message should explain empty object issue")
                #expect(context.debugDescription.contains("Expected format"),
                       "Error message should provide format guidance")
                #expect(context.debugDescription.contains("Example"),
                       "Error message should include examples")
            } else {
                #expect(Bool(false), "Expected dataCorrupted error")
            }
        }
    }

    @Test("Enhanced Error Messages - Invalid Character Multiple Characters")
    func testEnhancedErrorMessageInvalidCharacterMultiple() throws {
        let decoder = JSONDecoder()
        let multiCharData = Data("{ \"character\": \"ABC\" }".utf8)

        do {
            _ = try decoder.decode(Literal.self, from: multiCharData)
            #expect(Bool(false), "Should have thrown an error for multiple characters")
        } catch let error as DecodingError {
            if case .dataCorrupted(let context) = error {
                #expect(context.debugDescription.contains("multiple characters"),
                       "Error should mention multiple characters issue")
                #expect(context.debugDescription.contains("length: 3"),
                       "Error should show the actual length")
                #expect(context.debugDescription.contains("string literal"),
                       "Error should suggest using string literal")
            } else {
                #expect(Bool(false), "Expected dataCorrupted error")
            }
        }
    }

    @Test("Enhanced Error Messages - Invalid Character Empty String")
    func testEnhancedErrorMessageInvalidCharacterEmpty() throws {
        let decoder = JSONDecoder()
        let emptyCharData = Data("{ \"character\": \"\" }".utf8)

        do {
            _ = try decoder.decode(Literal.self, from: emptyCharData)
            #expect(Bool(false), "Should have thrown an error for empty character")
        } catch let error as DecodingError {
            if case .dataCorrupted(let context) = error {
                #expect(context.debugDescription.contains("empty string"),
                       "Error should mention empty string issue")
                #expect(context.debugDescription.contains("exactly one character"),
                       "Error should specify requirement")
            } else {
                #expect(Bool(false), "Expected dataCorrupted error")
            }
        }
    }

    @Test("Enhanced Error Messages - Typo Detection")
    func testEnhancedErrorMessageTypoDetection() throws {
        let decoder = JSONDecoder()
        let typoData = Data("{ \"integr\": 42 }".utf8) // "integr" instead of "integer"

        do {
            _ = try decoder.decode(Literal.self, from: typoData)
            #expect(Bool(false), "Should have thrown an error for typo")
        } catch let error as DecodingError {
            if case .dataCorrupted(let context) = error {
                #expect(context.debugDescription.contains("Did you mean"),
                       "Error should provide typo suggestions")
                #expect(context.debugDescription.contains("integer"),
                       "Error should suggest 'integer'")
                #expect(context.debugDescription.contains("Examples"),
                       "Error should include examples")
            } else {
                #expect(Bool(false), "Expected dataCorrupted error")
            }
        }
    }

    // MARK: - Enhanced Numeric Handling Tests

    @Test("Enhanced Real Value Decoding - Additional Types")
    func testEnhancedRealValueDecodingAdditionalTypes() throws {
        let decoder = JSONDecoder()

        // Test Float input (should be supported now)
        let floatData = Data("{ \"real\": 3.14 }".utf8)
        let floatLiteral = try decoder.decode(Literal.self, from: floatData)

        if case let .real(value) = floatLiteral {
            #expect(abs(value - 3.14) < 0.001, "Float should be converted to Double correctly")
        } else {
            #expect(Bool(false), "Expected real literal")
        }

        // Test scientific notation
        let scientificData = Data("{ \"real\": 1.23e-4 }".utf8)
        let scientificLiteral = try decoder.decode(Literal.self, from: scientificData)

        if case let .real(value) = scientificLiteral {
            #expect(abs(value - 0.000123) < 0.0000001, "Scientific notation should be handled correctly")
        } else {
            #expect(Bool(false), "Expected real literal")
        }
    }

    @Test("Enhanced Real Value Validation - Special Values")
    func testEnhancedRealValueValidationSpecialValues() throws {
        // Note: These tests document the current behavior where JSONEncoder rejects 
        // infinity and NaN values during encoding, before our validation even runs

        let infinityLiteral = Literal.real(Double.infinity)
        let nanLiteral = Literal.real(Double.nan)
        let encoder = JSONEncoder()

        // Test that our implementation properly handles special values during encoding
        #expect(throws: EncodingError.self) {
            _ = try encoder.encode(infinityLiteral)
        }

        #expect(throws: EncodingError.self) {
            _ = try encoder.encode(nanLiteral)
        }
    }

    @Test("Enhanced Real Value Error Messages")
    func testEnhancedRealValueErrorMessages() throws {
        let decoder = JSONDecoder()
        let invalidRealData = Data("{ \"real\": \"not_a_number\" }".utf8)

        do {
            _ = try decoder.decode(Literal.self, from: invalidRealData)
            #expect(Bool(false), "Should have thrown an error for invalid real value")
        } catch let error as DecodingError {
            if case .dataCorrupted(let context) = error {
                #expect(context.debugDescription.contains("Invalid literal value for real type"),
                       "Error should be specific about real type")
                #expect(context.debugDescription.contains("Supported types"),
                       "Error should list supported types")
                #expect(context.debugDescription.contains("Suggestion"),
                       "Error should provide suggestions")
            } else {
                #expect(Bool(false), "Expected dataCorrupted error")
            }
        }
    }

    // MARK: - Performance Optimization Tests

    @Test("Optimized SafeAnyCodable Performance")
    func testOptimizedSafeAnyCodablePerformance() throws {
        let iterations = 1000

        // Measure optimized SafeAnyCodable performance
        let startTime = CFAbsoluteTimeGetCurrent()

        for index in 0..<iterations {
            let anyCodable = try AnyCodableSafetyValidator.createSafeAnyCodable(index)
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let encoded = try encoder.encode(anyCodable)
            let decoded = try decoder.decode(SafeAnyCodable.self, from: encoded)
            let value: Int = try decoded.getValue()

            #expect(value == index, "Value should match")
        }

        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        let timePerOperation = totalTime / Double(iterations) * 1000 // Convert to milliseconds

        // Performance should be improved (allowing a tolerance window)
        let baselinePerformance = 0.02 // More realistic baseline in milliseconds  
        let tolerance = 0.05 // Wider allowable deviation to account for system variations
        let lowerBound = 0.001 // Minimum reasonable bound
        let upperBound = baselinePerformance + tolerance

        #expect(timePerOperation >= lowerBound && timePerOperation <= upperBound,
               "Optimized performance should be within \(lowerBound)ms and \(upperBound)ms per operation, got \(timePerOperation)ms")

        print("Optimized SafeAnyCodable performance: \(timePerOperation)ms per operation")
    }

    @Test("Type Tag Optimization Validation")
    func testTypeTagOptimizationValidation() throws {
        // Test that type tag optimization works correctly
        let intAnyCodable = try AnyCodableSafetyValidator.createSafeAnyCodable(42)
        let stringAnyCodable = try AnyCodableSafetyValidator.createSafeAnyCodable("test")

        // Fast type retrieval should work
        let intValue: Int = try intAnyCodable.getValue()
        let stringValue: String = try stringAnyCodable.getValue()

        #expect(intValue == 42, "Int value should be retrieved correctly")
        #expect(stringValue == "test", "String value should be retrieved correctly")

        // Wrong type access should fail fast
        #expect(throws: AnyCodableSafetyError.self) {
            let _: String = try intAnyCodable.getValue()
        }

        #expect(throws: AnyCodableSafetyError.self) {
            let _: Int = try stringAnyCodable.getValue()
        }

        // Optional access should work correctly
        let optionalInt: Int? = intAnyCodable.getValueOptional()
        let optionalWrongType: String? = intAnyCodable.getValueOptional()

        #expect(optionalInt == 42, "Optional access should work for correct type")
        #expect(optionalWrongType == nil, "Optional access should return nil for wrong type")
    }

    // MARK: - Round-trip Validation for Enhanced Features

    @Test("Enhanced Features Round-trip Validation")
    func testEnhancedFeaturesRoundTripValidation() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Test all literal types with enhanced implementation
        let testLiterals: [Literal] = [
            .integer(Int.max),
            .integer(Int.min),
            .integer(0),
            .real(Double.pi),
            .real(Double.leastNormalMagnitude),
            .real(Double.greatestFiniteMagnitude),
            .string("🎯 Enhanced Unicode Support 🌟"),
            .string(""),
            .character("🎮"),
            .character(" "),
            .boolean(true),
            .boolean(false)
        ]

        for literal in testLiterals {
            let encoded = try encoder.encode(literal)
            let decoded = try decoder.decode(Literal.self, from: encoded)

            #expect(decoded == literal, "Enhanced round-trip should preserve \(literal)")
        }
    }

    // MARK: - Backward Compatibility Tests

    @Test("Backward Compatibility with Existing JSON")
    func testBackwardCompatibilityWithExistingJSON() throws {
        let decoder = JSONDecoder()

        // Test that existing JSON still works with enhanced implementation
        let existingJSONSamples = [
            "{ \"integer\": 42 }",
            "{ \"real\": 3.14159 }",
            "{ \"string\": \"hello world\" }",
            "{ \"character\": \"A\" }",
            "{ \"boolean\": true }"
        ]

        let expectedLiterals: [Literal] = [
            .integer(42),
            .real(3.14159),
            .string("hello world"),
            .character("A"),
            .boolean(true)
        ]

        for (jsonString, expectedLiteral) in zip(existingJSONSamples, expectedLiterals) {
            let data = Data(jsonString.utf8)
            let decoded = try decoder.decode(Literal.self, from: data)

            #expect(decoded == expectedLiteral, "Backward compatibility failed for: \(jsonString)")
        }

        // Test that multiple keys now throw errors (enhanced behavior)
        let multipleKeysJSON = """
            { "real": 3.14, "integer": 42 }
        """

        do {
            _ = try decoder.decode(Literal.self, from: multipleKeysJSON.data(using: .utf8)!)
            #expect(Bool(false), "Should have thrown error for multiple keys")
        } catch {
            // This is the expected behavior now - multiple keys should be rejected
            #expect(error is DecodingError, "Should throw DecodingError for multiple keys")
            if case let DecodingError.dataCorrupted(context) = error {
                #expect(context.debugDescription.contains("Multiple keys found"), "Error should mention multiple keys")
            }
        }
    }

    // MARK: - Edge Case Regression Tests

    @Test("Edge Case Regression Prevention")
    func testEdgeCaseRegressionPrevention() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Test that previously discovered edge cases still work
        let edgeCaseLiterals: [Literal] = [
            .string(String(repeating: "🎯", count: 100)), // Large emoji string
            .string("\n\t\r"), // Whitespace characters
            .string("\"'`\\"), // Quote and escape characters
            .character("\n"), // Newline character
            .character("🎯"), // Emoji character
            .integer(0), // Zero
            .real(0.0), // Zero double
            .real(1e-10), // Very small number
            .real(1e10) // Large number
        ]

        for literal in edgeCaseLiterals {
            let encoded = try encoder.encode(literal)
            let decoded = try decoder.decode(Literal.self, from: encoded)

            #expect(decoded == literal, "Edge case regression detected for: \(literal)")
        }
    }
}
