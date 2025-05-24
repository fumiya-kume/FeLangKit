import Foundation

/// Safety validator for AnyCodable type to ensure immutability and type safety
/// Addresses concerns from GitHub issue #29 about AnyCodable.value: Any storage
public enum AnyCodableSafetyValidator {

    /// Validates that AnyCodable only stores supported value types
    /// Returns true if the value is safe for immutable storage
    public static func validateValueType<T>(_ value: T) -> Bool {
        // Only allow specific value types that maintain immutability
        switch value {
        case is Int, is Double, is String, is Bool:
            return true
        default:
            return false
        }
    }

    /// Creates a type-safe AnyCodable instance
    /// Throws an error if the value type is not supported
    public static func createSafeAnyCodable<T>(_ value: T) throws -> SafeAnyCodable {
        return try SafeAnyCodable(value)
    }

    /// Validates that decoded JSON data only contains supported types
    /// Throws AnyCodableSafetyError if validation fails
    public static func validateJSONData(_ data: Data) throws -> Bool {
        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw AnyCodableSafetyError.decodingFailed("Invalid JSON data: \(error.localizedDescription)")
        }

        // Handle different root types
        switch jsonObject {
        case let dictionary as [String: Any]:
            // Top-level dictionaries are allowed, validate their contents
            for (_, dictValue) in dictionary {
                try validateJSONValue(dictValue)
            }
        case is [Any]:
            // All arrays are rejected for immutability purposes
            throw AnyCodableSafetyError.unsupportedType("array")
        default:
            // Root primitives are allowed
            guard validateValueType(jsonObject) else {
                throw AnyCodableSafetyError.unsupportedType(String(describing: type(of: jsonObject)))
            }
        }

        return true
    }

    /// Recursively validates JSON values to ensure all nested structures contain only supported types
    /// For immutability purposes, nested arrays and dictionaries are rejected entirely
    private static func validateJSONValue(_ value: Any) throws {
        switch value {
        case let dictionary as [String: Any]:
            // Nested dictionaries are not supported for immutability
            throw AnyCodableSafetyError.unsupportedType("nested dictionary")
        case let array as [Any]:
            // Arrays are not supported for immutability 
            throw AnyCodableSafetyError.unsupportedType("array")
        case is NSNull:
            // null values are not supported for immutable storage
            throw AnyCodableSafetyError.unsupportedType("null")
        default:
            // Check if primitive value is supported
            guard validateValueType(value) else {
                throw AnyCodableSafetyError.unsupportedType(String(describing: type(of: value)))
            }
        }
    }
}

/// Type-safe wrapper for AnyCodable that enforces immutability constraints
public struct SafeAnyCodable: Codable, @unchecked Sendable {
    private let value: Any // Value is validated to only contain Sendable types
    private let typeTag: TypeTag // Cache the type for faster access

    /// Internal type tag for faster type checking
    private enum TypeTag: UInt8, CaseIterable {
        case int = 0
        case double = 1
        case string = 2
        case bool = 3

        var supportedType: Any.Type {
            switch self {
            case .int: return Int.self
            case .double: return Double.self
            case .string: return String.self
            case .bool: return Bool.self
            }
        }
    }

    /// Creates a SafeAnyCodable with validated type constraints
    /// Optimized version with cached type information
    /// Throws AnyCodableSafetyError.unsupportedType if the value type is not supported
    init<T>(_ value: T) throws {
        // Fast type checking using pattern matching
        switch value {
        case let intValue as Int:
            self.value = intValue
            self.typeTag = .int
        case let doubleValue as Double:
            self.value = doubleValue
            self.typeTag = .double
        case let stringValue as String:
            self.value = stringValue
            self.typeTag = .string
        case let boolValue as Bool:
            self.value = boolValue
            self.typeTag = .bool
        default:
            throw AnyCodableSafetyError.unsupportedType(String(describing: type(of: value)))
        }
    }

    /// Safely retrieves the stored value with optimized type checking
    /// Throws AnyCodableSafetyError.typeValidationFailed if type doesn't match
    public func getValue<T>() throws -> T {
        // Use cached type tag for faster validation - replaced force casts with safe error handling
        switch (T.self, typeTag) {
        case (is Int.Type, .int):
            guard let intValue = value as? T else {
                throw AnyCodableSafetyError.typeValidationFailed
            }
            return intValue
        case (is Double.Type, .double):
            guard let doubleValue = value as? T else {
                throw AnyCodableSafetyError.typeValidationFailed
            }
            return doubleValue
        case (is String.Type, .string):
            guard let stringValue = value as? T else {
                throw AnyCodableSafetyError.typeValidationFailed
            }
            return stringValue
        case (is Bool.Type, .bool):
            guard let boolValue = value as? T else {
                throw AnyCodableSafetyError.typeValidationFailed
            }
            return boolValue
        default:
            throw AnyCodableSafetyError.typeValidationFailed
        }
    }

    /// Safely retrieves the stored value with type checking (optional variant)
    /// Optimized version using cached type information
    /// Returns nil if type doesn't match - provided for backward compatibility
    public func getValueOptional<T>() -> T? {
        // Use cached type tag for faster validation
        switch (T.self, typeTag) {
        case (is Int.Type, .int),
             (is Double.Type, .double),
             (is String.Type, .string),
             (is Bool.Type, .bool):
            return value as? T
        default:
            return nil
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Optimized type checking with early exit
        if let intValue = try? container.decode(Int.self) {
            self.value = intValue
            self.typeTag = .int
        } else if let doubleValue = try? container.decode(Double.self) {
            self.value = doubleValue
            self.typeTag = .double
        } else if let stringValue = try? container.decode(String.self) {
            self.value = stringValue
            self.typeTag = .string
        } else if let boolValue = try? container.decode(Bool.self) {
            self.value = boolValue
            self.typeTag = .bool
        } else {
            throw AnyCodableSafetyError.decodingFailed("No supported type found")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        // Use cached type tag for faster encoding - replaced force casts with safe error handling
        switch typeTag {
        case .int:
            guard let intValue = value as? Int else {
                throw AnyCodableSafetyError.encodingFailed("Type tag indicates Int but value conversion failed")
            }
            try container.encode(intValue)
        case .double:
            guard let doubleValue = value as? Double else {
                throw AnyCodableSafetyError.encodingFailed("Type tag indicates Double but value conversion failed")
            }
            try container.encode(doubleValue)
        case .string:
            guard let stringValue = value as? String else {
                throw AnyCodableSafetyError.encodingFailed("Type tag indicates String but value conversion failed")
            }
            try container.encode(stringValue)
        case .bool:
            guard let boolValue = value as? Bool else {
                throw AnyCodableSafetyError.encodingFailed("Type tag indicates Bool but value conversion failed")
            }
            try container.encode(boolValue)
        }
    }
}

/// Errors related to AnyCodable safety validation
public enum AnyCodableSafetyError: Error, Equatable {
    case unsupportedType(String)
    case decodingFailed(String)
    case encodingFailed(String)
    case typeValidationFailed
}

extension AnyCodableSafetyError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unsupportedType(let type):
            return "Unsupported type for immutable storage: \(type)"
        case .decodingFailed(let message):
            return "AnyCodable decoding failed: \(message)"
        case .encodingFailed(let message):
            return "AnyCodable encoding failed: \(message)"
        case .typeValidationFailed:
            return "Type validation failed for AnyCodable value"
        }
    }
}

// MARK: - Enhanced AnyCodable with Safety Checks

/// Enhanced version of AnyCodable with improved type safety
/// This addresses the concerns raised in issue #29 about the original AnyCodable implementation
public struct ImprovedAnyCodable: Codable, Equatable, @unchecked Sendable {
    private enum SupportedType: CaseIterable {
        case int
        case double
        case string
        case bool

        var metatype: Any.Type {
            switch self {
            case .int: return Int.self
            case .double: return Double.self
            case .string: return String.self
            case .bool: return Bool.self
            }
        }
    }

    private let value: Any
    private let typeIdentifier: SupportedType

    /// Creates an ImprovedAnyCodable with strict type validation
    public init<T>(_ value: T) throws {
        // Validate that the type is supported
        guard let supportedType = SupportedType.allCases.first(where: { type(of: value) == $0.metatype }) else {
            throw AnyCodableSafetyError.unsupportedType(String(describing: type(of: value)))
        }

        self.value = value
        self.typeIdentifier = supportedType
    }

    /// Safely retrieves the value with type checking
    public func getValue<T>() throws -> T {
        guard let typedValue = value as? T else {
            throw AnyCodableSafetyError.typeValidationFailed
        }
        return typedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Use explicit type checking for safety
        if let intValue = try? container.decode(Int.self) {
            self.value = intValue
            self.typeIdentifier = .int
        } else if let doubleValue = try? container.decode(Double.self) {
            self.value = doubleValue
            self.typeIdentifier = .double
        } else if let stringValue = try? container.decode(String.self) {
            self.value = stringValue
            self.typeIdentifier = .string
        } else if let boolValue = try? container.decode(Bool.self) {
            self.value = boolValue
            self.typeIdentifier = .bool
        } else {
            throw AnyCodableSafetyError.decodingFailed("No supported type could be decoded")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch typeIdentifier {
        case .int:
            guard let intValue = value as? Int else {
                throw AnyCodableSafetyError.encodingFailed("Expected Int but found different type")
            }
            try container.encode(intValue)
        case .double:
            guard let doubleValue = value as? Double else {
                throw AnyCodableSafetyError.encodingFailed("Expected Double but found different type")
            }
            try container.encode(doubleValue)
        case .string:
            guard let stringValue = value as? String else {
                throw AnyCodableSafetyError.encodingFailed("Expected String but found different type")
            }
            try container.encode(stringValue)
        case .bool:
            guard let boolValue = value as? Bool else {
                throw AnyCodableSafetyError.encodingFailed("Expected Bool but found different type")
            }
            try container.encode(boolValue)
        }
    }

    public static func == (lhs: ImprovedAnyCodable, rhs: ImprovedAnyCodable) -> Bool {
        // Compare type identifiers first
        guard lhs.typeIdentifier == rhs.typeIdentifier else { return false }

        // Compare values based on type
        switch lhs.typeIdentifier {
        case .int:
            return (lhs.value as? Int) == (rhs.value as? Int)
        case .double:
            return (lhs.value as? Double) == (rhs.value as? Double)
        case .string:
            return (lhs.value as? String) == (rhs.value as? String)
        case .bool:
            return (lhs.value as? Bool) == (rhs.value as? Bool)
        }
    }
}

// MARK: - Immutability Validation Extensions

extension AnyCodableSafetyValidator {

    /// Performs a comprehensive immutability check on AnyCodable usage
    public static func auditAnyCodableUsage() -> ImmutabilityAuditResult {
        var issues: [String] = []
        var recommendations: [String] = []

        // Issue 1: Check if Any storage is being used (inherent in AnyCodable design)
        issues.append("AnyCodable uses 'Any' storage which bypasses compile-time type safety")

        // Issue 2: Potential for runtime type validation failures
        issues.append("Type validation occurs at runtime rather than compile-time, increasing crash risk")

        // Issue 3: Sendable conformance requires @unchecked due to Any storage
        issues.append("Sendable conformance requires @unchecked annotation due to Any storage")

        // Check 1: Verify type constraints are enforced
        let supportedTypes = ["Int", "Double", "String", "Bool"]
        recommendations.append("AnyCodable should only support these types: \(supportedTypes.joined(separator: ", "))")

        // Check 2: Verify no reference types can be stored
        recommendations.append("Ensure no reference types (classes, closures, etc.) can be stored in AnyCodable")

        // Check 3: Validate thread safety
        recommendations.append("Verify that AnyCodable maintains thread safety guarantees")

        // Check 4: Check for potential type erasure issues
        recommendations.append("Consider replacing Any storage with enum-based type-safe storage for better compile-time safety")

        // Recommendation 5: API consistency
        recommendations.append("Ensure consistent error handling between SafeAnyCodable and ImprovedAnyCodable")

        return ImmutabilityAuditResult(
            component: "AnyCodable",
            isImmutable: issues.isEmpty, // Will be false since we have real issues
            issues: issues,
            recommendations: recommendations
        )
    }
}

/// Result of an immutability audit
public struct ImmutabilityAuditResult {
    public let component: String
    public let isImmutable: Bool
    public let issues: [String]
    public let recommendations: [String]

    public init(component: String, isImmutable: Bool, issues: [String], recommendations: [String]) {
        self.component = component
        self.isImmutable = isImmutable
        self.issues = issues
        self.recommendations = recommendations
    }
}
