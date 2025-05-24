import Testing
@testable import FeLangCore
import Foundation

/// Tests for AnyCodable Safety Analysis
/// Addresses Child Issue #32: AnyCodable Safety Analysis from GitHub issue #29
@Suite("AnyCodable Safety Analysis")
struct AnyCodableSafetyTests {

    // MARK: - Type Safety Validation Tests

    @Test("Validate Value Type Restrictions")
    func testValidateValueTypeRestrictions() throws {
        // Test supported types
        #expect(AnyCodableSafetyValidator.validateValueType(42))
        #expect(AnyCodableSafetyValidator.validateValueType(3.14))
        #expect(AnyCodableSafetyValidator.validateValueType("test"))
        #expect(AnyCodableSafetyValidator.validateValueType(true))
        #expect(AnyCodableSafetyValidator.validateValueType(Character("A")))

        // Test unsupported types - these should all return false
        #expect(!AnyCodableSafetyValidator.validateValueType([1, 2, 3])) // Array
        #expect(!AnyCodableSafetyValidator.validateValueType(["key": "value"])) // Dictionary
        #expect(!AnyCodableSafetyValidator.validateValueType(NSObject())) // Reference type
        #expect(!AnyCodableSafetyValidator.validateValueType(Data())) // Complex value type

        // Test closure (should not be supported)
        let closure = { print("test") }
        #expect(!AnyCodableSafetyValidator.validateValueType(closure))
    }

    @Test("Safe AnyCodable Creation")
    func testSafeAnyCodableCreation() throws {
        // Test successful creation with supported types
        let intAnyCodable = try AnyCodableSafetyValidator.createSafeAnyCodable(42)
        let stringAnyCodable = try AnyCodableSafetyValidator.createSafeAnyCodable("test")
        let boolAnyCodable = try AnyCodableSafetyValidator.createSafeAnyCodable(true)

        // Verify values can be retrieved
        #expect(intAnyCodable.getValue() == 42)
        #expect(stringAnyCodable.getValue() == "test")
        #expect(boolAnyCodable.getValue() == true)

        // Test that unsupported types throw errors
        #expect(throws: AnyCodableSafetyError.self) {
            _ = try AnyCodableSafetyValidator.createSafeAnyCodable([1, 2, 3])
        }

        #expect(throws: AnyCodableSafetyError.self) {
            _ = try AnyCodableSafetyValidator.createSafeAnyCodable(NSObject())
        }
    }

    @Test("JSON Data Validation")
    func testJSONDataValidation() throws {
        // Test valid JSON with supported types
        let validJSON = Data("""
        {
            "integer": 42,
            "string": "test",
            "boolean": true,
            "real": 3.14
        }
        """.utf8)

        #expect(try AnyCodableSafetyValidator.validateJSONData(validJSON))

        // Test invalid JSON with unsupported nested structures
        let invalidJSON = Data("""
        {
            "array": [1, 2, 3],
            "nested": {"key": "value"}
        }
        """.utf8)

        #expect(throws: AnyCodableSafetyError.self) {
            _ = try AnyCodableSafetyValidator.validateJSONData(invalidJSON)
        }
    }

    // MARK: - SafeAnyCodable Tests

    @Test("SafeAnyCodable Encoding and Decoding")
    func testSafeAnyCodableEncodingDecoding() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Test various supported types
        let testValues: [(Any, String)] = [
            (42, "Int"),
            (3.14, "Double"),
            ("test", "String"),
            (true, "Bool")
        ]

        for (value, typeName) in testValues {
            let safeAnyCodable = try AnyCodableSafetyValidator.createSafeAnyCodable(value)

            // Test encoding
            let encoded = try encoder.encode(safeAnyCodable)
            #expect(!encoded.isEmpty, "Encoded data should not be empty for \(typeName)")

            // Test decoding
            let decoded = try decoder.decode(SafeAnyCodable.self, from: encoded)

            // Verify values match
            switch value {
            case let intValue as Int:
                #expect(decoded.getValue() == intValue, "Int value should match")
            case let doubleValue as Double:
                #expect(decoded.getValue() == doubleValue, "Double value should match")
            case let stringValue as String:
                #expect(decoded.getValue() == stringValue, "String value should match")
            case let boolValue as Bool:
                #expect(decoded.getValue() == boolValue, "Bool value should match")
            default:
                #expect(Bool(false), "Unexpected type in test")
            }
        }
    }

    @Test("SafeAnyCodable Error Handling")
    func testSafeAnyCodableErrorHandling() throws {
        // Test decoding invalid data
        let invalidData = Data("""
        {"unsupported": [1, 2, 3]}
        """.utf8)

        let decoder = JSONDecoder()

        #expect(throws: AnyCodableSafetyError.self) {
            _ = try decoder.decode(SafeAnyCodable.self, from: invalidData)
        }

        // Test empty data
        let emptyData = Data("{}".utf8)

        #expect(throws: AnyCodableSafetyError.self) {
            _ = try decoder.decode(SafeAnyCodable.self, from: emptyData)
        }
    }

    // MARK: - ImprovedAnyCodable Tests

    @Test("ImprovedAnyCodable Type Safety")
    func testImprovedAnyCodableTypeSafety() throws {
        // Test creation with supported types
        let intCodable = try ImprovedAnyCodable(42)
        let stringCodable = try ImprovedAnyCodable("test")
        let boolCodable = try ImprovedAnyCodable(true)
        let doubleCodable = try ImprovedAnyCodable(3.14)

        // Test value retrieval
        #expect(try intCodable.getValue() == 42)
        #expect(try stringCodable.getValue() == "test")
        #expect(try boolCodable.getValue() == true)
        #expect(try doubleCodable.getValue() as Double == 3.14)

        // Test that unsupported types are rejected
        #expect(throws: AnyCodableSafetyError.self) {
            _ = try ImprovedAnyCodable([1, 2, 3])
        }

        #expect(throws: AnyCodableSafetyError.self) {
            _ = try ImprovedAnyCodable(NSObject())
        }
    }

    @Test("ImprovedAnyCodable Equality")
    func testImprovedAnyCodableEquality() throws {
        let int1 = try ImprovedAnyCodable(42)
        let int2 = try ImprovedAnyCodable(42)
        let int3 = try ImprovedAnyCodable(99)

        let string1 = try ImprovedAnyCodable("test")
        let string2 = try ImprovedAnyCodable("test")

        // Test equality
        #expect(int1 == int2)
        #expect(int1 != int3)
        #expect(string1 == string2)
        #expect(int1 != string1) // Different types should not be equal

        // Test reflexivity
        #expect(int1 == int1)

        // Test symmetry
        #expect((int1 == int2) == (int2 == int1))
    }

    @Test("ImprovedAnyCodable Encoding and Decoding")
    func testImprovedAnyCodableEncodingDecoding() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = try ImprovedAnyCodable(42)

        // Test round-trip encoding/decoding
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(ImprovedAnyCodable.self, from: encoded)

        #expect(original == decoded)
        #expect(try decoded.getValue() == 42)
    }

    // MARK: - Original AnyCodable Analysis

    @Test("Original AnyCodable Implementation Analysis")
    func testOriginalAnyCodableImplementationAnalysis() throws {
        // Test the existing AnyCodable implementation through Literal decoding
        // This tests the current implementation's behavior

        let validLiteralJSON = Data("""
        {"integer": 42}
        """.utf8)

        let decoder = JSONDecoder()
        let literal = try decoder.decode(Literal.self, from: validLiteralJSON)

        #expect(literal == .integer(42))

        // Test all literal types to ensure current implementation works
        let literalTestCases = [
            ("{\"integer\": 123}", Literal.integer(123)),
            ("{\"real\": 3.14}", Literal.real(3.14)),
            ("{\"string\": \"test\"}", Literal.string("test")),
            ("{\"character\": \"A\"}", Literal.character("A")),
            ("{\"boolean\": true}", Literal.boolean(true))
        ]

        for (json, expectedLiteral) in literalTestCases {
            let data = Data(json.utf8)
            let decodedLiteral = try decoder.decode(Literal.self, from: data)
            #expect(decodedLiteral == expectedLiteral)
        }
    }

    @Test("Original AnyCodable Constraints Verification")
    func testOriginalAnyCodableConstraintsVerification() throws {
        // Verify that the original AnyCodable implementation in Expression.swift
        // properly restricts types during decoding

        // Test invalid literal data that should fail
        let invalidLiteralJSON = Data("""
        {"unsupported": [1, 2, 3]}
        """.utf8)

        let decoder = JSONDecoder()

        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(Literal.self, from: invalidLiteralJSON)
        }

        // Test empty object
        let emptyJSON = Data("{}".utf8)

        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(Literal.self, from: emptyJSON)
        }
    }

    // MARK: - Immutability Audit

    @Test("AnyCodable Immutability Audit")
    func testAnyCodableImmutabilityAudit() throws {
        let auditResult = AnyCodableSafetyValidator.auditAnyCodableUsage()

        #expect(auditResult.component == "AnyCodable")
        #expect(!auditResult.recommendations.isEmpty)

        // Verify audit identifies key concerns
        let recommendations = auditResult.recommendations.joined(separator: " ")
        #expect(recommendations.contains("type"))
        #expect(recommendations.contains("thread safety") || recommendations.contains("Sendable"))
    }

    @Test("Thread Safety Verification")
    func testThreadSafetyVerification() async throws {
        // Test that SafeAnyCodable maintains thread safety
        let sharedSafeAnyCodable = try AnyCodableSafetyValidator.createSafeAnyCodable(42)

        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<10 {
                group.addTask { @Sendable in
                    // Concurrent access to the shared SafeAnyCodable
                    let value: Int? = sharedSafeAnyCodable.getValue()
                    return value == 42
                }
            }

            var allSuccess = true
            for await result in group {
                allSuccess = allSuccess && result
            }

            #expect(allSuccess, "Concurrent access to SafeAnyCodable should be thread-safe")
        }
    }

    @Test("Memory Safety - Value Semantics")
    func testMemorySafetyValueSemantics() throws {
        // Test that AnyCodable types maintain value semantics
        let original = try ImprovedAnyCodable(42)
        let copy = original

        #expect(original == copy)

        // Since ImprovedAnyCodable is a struct, modifications should not affect copies
        // (though ImprovedAnyCodable is immutable by design)

        // Test with different values
        let different = try ImprovedAnyCodable(99)
        #expect(original != different)
        #expect(copy == original) // Copy should still equal original
    }

    @Test("Type Erasure Safety")
    func testTypeErasureSafety() throws {
        // Test that type erasure doesn't compromise type safety
        let items: [Any] = [
            try ImprovedAnyCodable(42),
            try ImprovedAnyCodable("test"),
            try ImprovedAnyCodable(true)
        ]

        // Even when type-erased, we should be able to work with them safely
        for item in items {
            if let anyCodable = item as? ImprovedAnyCodable {
                // Should be able to encode/decode safely
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()

                let encoded = try encoder.encode(anyCodable)
                let decoded = try decoder.decode(ImprovedAnyCodable.self, from: encoded)

                #expect(anyCodable == decoded)
            }
        }
    }

    // MARK: - Integration with AST Types

    @Test("Integration with Literal Type")
    func testIntegrationWithLiteralType() throws {
        // Test that our safety improvements integrate well with existing Literal usage

        // Create literals through existing API
        let literals: [Literal] = [
            .integer(42),
            .real(3.14),
            .string("test"),
            .character("A"),
            .boolean(true)
        ]

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for literal in literals {
            // Test that existing Literal encoding/decoding still works
            let encoded = try encoder.encode(literal)
            let decoded = try decoder.decode(Literal.self, from: encoded)

            #expect(decoded == literal, "Literal round-trip should preserve value")

            // Verify that the JSON structure is what we expect
            let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
            #expect(json != nil, "Should produce valid JSON")
            #expect(json?.keys.count == 1, "Should have exactly one key-value pair")
        }
    }
}
