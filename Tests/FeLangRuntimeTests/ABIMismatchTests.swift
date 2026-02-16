import XCTest
@testable import FeLangRuntime

final class ABIMismatchTests: XCTestCase {

    // MARK: - Spec Integrity

    func testAllFunctionNamesAreUnique() {
        let names = RuntimeABISpec.allFunctions.map(\.name)
        let uniqueNames = Set(names)
        XCTAssertEqual(
            names.count,
            uniqueNames.count,
            "Duplicate function names found in RuntimeABISpec"
        )
    }

    func testAllFunctionNamesFollowKKPrefix() {
        for spec in RuntimeABISpec.allFunctions {
            XCTAssertTrue(
                spec.name.hasPrefix("kk_"),
                "Function '\(spec.name)' does not follow kk_ naming convention"
            )
        }
    }

    func testSpecVersionIsNonEmpty() {
        XCTAssertFalse(RuntimeABISpec.specVersion.isEmpty)
    }

    func testAllFunctionsHaveDescriptions() {
        for spec in RuntimeABISpec.allFunctions {
            XCTAssertFalse(
                spec.description.isEmpty,
                "Function '\(spec.name)' is missing a description"
            )
        }
    }

    func testAllParameterNamesAreNonEmpty() {
        for spec in RuntimeABISpec.allFunctions {
            for param in spec.parameters {
                XCTAssertFalse(
                    param.name.isEmpty,
                    "Parameter in '\(spec.name)' has an empty name"
                )
            }
        }
    }

    func testParameterNamesUniquePerFunction() {
        for spec in RuntimeABISpec.allFunctions {
            let names = spec.parameters.map(\.name)
            let uniqueNames = Set(names)
            XCTAssertEqual(
                names.count,
                uniqueNames.count,
                "Duplicate parameter names in '\(spec.name)'"
            )
        }
    }

    // MARK: - Category Counts

    func testMemoryFunctionCount() {
        XCTAssertEqual(RuntimeABISpec.memoryFunctions.count, 5)
    }

    func testValueCreationFunctionCount() {
        XCTAssertEqual(RuntimeABISpec.valueCreationFunctions.count, 5)
    }

    func testValueAccessFunctionCount() {
        XCTAssertEqual(RuntimeABISpec.valueAccessFunctions.count, 6)
    }

    func testIOFunctionCount() {
        XCTAssertEqual(RuntimeABISpec.ioFunctions.count, 3)
    }

    func testArrayFunctionCount() {
        XCTAssertEqual(RuntimeABISpec.arrayFunctions.count, 5)
    }

    func testEnvironmentFunctionCount() {
        XCTAssertEqual(RuntimeABISpec.environmentFunctions.count, 7)
    }

    func testTotalFunctionCount() {
        let expected = RuntimeABISpec.memoryFunctions.count
            + RuntimeABISpec.valueCreationFunctions.count
            + RuntimeABISpec.valueAccessFunctions.count
            + RuntimeABISpec.ioFunctions.count
            + RuntimeABISpec.arrayFunctions.count
            + RuntimeABISpec.environmentFunctions.count
        XCTAssertEqual(RuntimeABISpec.allFunctions.count, expected)
    }

    // MARK: - Nullable Policy

    func testKKAllocReturnsNullable() {
        let spec = RuntimeABISpec.allFunctions.first { $0.name == "kk_alloc" }
        XCTAssertNotNil(spec)
        XCTAssertEqual(spec?.returnType, .nullableOpaquePointer)
    }

    func testKKReallocReturnsNullable() {
        let spec = RuntimeABISpec.allFunctions.first { $0.name == "kk_realloc" }
        XCTAssertNotNil(spec)
        XCTAssertEqual(spec?.returnType, .nullableOpaquePointer)
    }

    func testKKFreeAcceptsNullablePointer() {
        let spec = RuntimeABISpec.allFunctions.first { $0.name == "kk_free" }
        XCTAssertNotNil(spec)
        XCTAssertEqual(spec?.parameters.first?.type, .nullableOpaquePointer)
    }

    func testKKValueCreatorsReturnNonNullable() {
        for funcSpec in RuntimeABISpec.valueCreationFunctions {
            XCTAssertEqual(
                funcSpec.returnType,
                .opaquePointer,
                "Value creator '\(funcSpec.name)' should return non-nullable pointer"
            )
        }
    }

    func testKKInputReturnsNullable() {
        let spec = RuntimeABISpec.allFunctions.first { $0.name == "kk_input" }
        XCTAssertNotNil(spec)
        XCTAssertEqual(spec?.returnType, .nullableCString)
    }

    func testKKEnvGetReturnsNullable() {
        let spec = RuntimeABISpec.allFunctions.first { $0.name == "kk_env_get" }
        XCTAssertNotNil(spec)
        XCTAssertEqual(spec?.returnType, .nullableOpaquePointer)
    }

    // MARK: - Specific Signature Checks

    func testKKAllocSignature() {
        guard let spec = RuntimeABISpec.allFunctions.first(where: { $0.name == "kk_alloc" }) else {
            XCTFail("kk_alloc not found in spec")
            return
        }
        XCTAssertEqual(spec.parameters.count, 1)
        XCTAssertEqual(spec.parameters[0].name, "size")
        XCTAssertEqual(spec.parameters[0].type, .int64)
    }

    func testKKValueIntegerSignature() {
        guard let spec = RuntimeABISpec.allFunctions.first(where: { $0.name == "kk_value_integer" }) else {
            XCTFail("kk_value_integer not found in spec")
            return
        }
        XCTAssertEqual(spec.returnType, .opaquePointer)
        XCTAssertEqual(spec.parameters.count, 1)
        XCTAssertEqual(spec.parameters[0].type, .int64)
    }

    func testKKValueStringSignature() {
        guard let spec = RuntimeABISpec.allFunctions.first(where: { $0.name == "kk_value_string" }) else {
            XCTFail("kk_value_string not found in spec")
            return
        }
        XCTAssertEqual(spec.returnType, .opaquePointer)
        XCTAssertEqual(spec.parameters.count, 2)
        XCTAssertEqual(spec.parameters[0].type, .cString)
        XCTAssertEqual(spec.parameters[1].type, .int64)
    }

    func testKKEnvDefineSignature() {
        guard let spec = RuntimeABISpec.allFunctions.first(where: { $0.name == "kk_env_define" }) else {
            XCTFail("kk_env_define not found in spec")
            return
        }
        XCTAssertEqual(spec.returnType, .void)
        XCTAssertEqual(spec.parameters.count, 3)
        XCTAssertEqual(spec.parameters[0].type, .opaquePointer)
        XCTAssertEqual(spec.parameters[1].type, .cString)
        XCTAssertEqual(spec.parameters[2].type, .opaquePointer)
    }

    // MARK: - C Declaration Generation

    func testCDeclarationForKKAlloc() {
        guard let spec = RuntimeABISpec.allFunctions.first(where: { $0.name == "kk_alloc" }) else {
            XCTFail("kk_alloc not found in spec")
            return
        }
        XCTAssertEqual(
            spec.cDeclaration,
            "void * _Nullable kk_alloc(int64_t size);"
        )
    }

    func testCDeclarationForKKFree() {
        guard let spec = RuntimeABISpec.allFunctions.first(where: { $0.name == "kk_free" }) else {
            XCTFail("kk_free not found in spec")
            return
        }
        XCTAssertEqual(
            spec.cDeclaration,
            "void kk_free(void * _Nullable ptr);"
        )
    }

    func testCDeclarationForKKValueNull() {
        guard let spec = RuntimeABISpec.allFunctions.first(where: { $0.name == "kk_value_null" }) else {
            XCTFail("kk_value_null not found in spec")
            return
        }
        XCTAssertEqual(
            spec.cDeclaration,
            "void * kk_value_null(void);"
        )
    }

    // MARK: - Header Generator vs Canonical Header

    func testGeneratedHeaderMatchesCanonicalHeader() {
        let generated = ABIHeaderGenerator.generate()
        let canonicalURL = Bundle.module.url(
            forResource: "felang_runtime_abi",
            withExtension: "h"
        )
        guard let url = canonicalURL else {
            XCTFail("Canonical header resource 'felang_runtime_abi.h' not found in test bundle")
            return
        }
        guard let canonical = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("Failed to read canonical header at \(url)")
            return
        }
        XCTAssertEqual(
            normalizeWhitespace(generated),
            normalizeWhitespace(canonical),
            "Generated header does not match canonical header. Re-run the header generator."
        )
    }

    func testGeneratedHeaderContainsAllFunctionNames() {
        let generated = ABIHeaderGenerator.generate()
        for spec in RuntimeABISpec.allFunctions {
            XCTAssertTrue(
                generated.contains(spec.name),
                "Generated header is missing function '\(spec.name)'"
            )
        }
    }

    func testGeneratedHeaderContainsIncludeGuard() {
        let generated = ABIHeaderGenerator.generate()
        XCTAssertTrue(generated.contains("#ifndef FELANG_RUNTIME_ABI_H"))
        XCTAssertTrue(generated.contains("#define FELANG_RUNTIME_ABI_H"))
        XCTAssertTrue(generated.contains("#endif /* FELANG_RUNTIME_ABI_H */"))
    }

    func testGeneratedHeaderContainsRequiredIncludes() {
        let generated = ABIHeaderGenerator.generate()
        XCTAssertTrue(generated.contains("#include <stdint.h>"))
        XCTAssertTrue(generated.contains("#include <stdbool.h>"))
        XCTAssertTrue(generated.contains("#include <stddef.h>"))
    }

    func testGeneratedHeaderContainsCppGuard() {
        let generated = ABIHeaderGenerator.generate()
        XCTAssertTrue(generated.contains("#ifdef __cplusplus"))
        XCTAssertTrue(generated.contains("extern \"C\" {"))
    }

    // MARK: - ABIType Properties

    func testABITypeCTypeNames() {
        XCTAssertEqual(ABIType.void.cTypeName, "void")
        XCTAssertEqual(ABIType.int32.cTypeName, "int32_t")
        XCTAssertEqual(ABIType.int64.cTypeName, "int64_t")
        XCTAssertEqual(ABIType.float64.cTypeName, "double")
        XCTAssertEqual(ABIType.bool.cTypeName, "bool")
        XCTAssertEqual(ABIType.opaquePointer.cTypeName, "void *")
        XCTAssertEqual(ABIType.nullableOpaquePointer.cTypeName, "void * _Nullable")
        XCTAssertEqual(ABIType.cString.cTypeName, "const char *")
        XCTAssertEqual(ABIType.nullableCString.cTypeName, "const char * _Nullable")
    }

    func testABITypeNullability() {
        XCTAssertFalse(ABIType.void.isNullable)
        XCTAssertFalse(ABIType.int32.isNullable)
        XCTAssertFalse(ABIType.opaquePointer.isNullable)
        XCTAssertFalse(ABIType.cString.isNullable)
        XCTAssertTrue(ABIType.nullableOpaquePointer.isNullable)
        XCTAssertTrue(ABIType.nullableCString.isNullable)
    }

    // MARK: - Helpers

    private func normalizeWhitespace(_ str: String) -> String {
        str.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
