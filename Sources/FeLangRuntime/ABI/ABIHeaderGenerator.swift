import Foundation

public enum ABIHeaderGenerator {
    public static func generate(
        functions: [ABIFunctionSpec] = RuntimeABISpec.allFunctions,
        version: String = RuntimeABISpec.specVersion
    ) -> String {
        var lines: [String] = []

        lines.append("#ifndef FELANG_RUNTIME_ABI_H")
        lines.append("#define FELANG_RUNTIME_ABI_H")
        lines.append("")
        lines.append("#include <stdint.h>")
        lines.append("#include <stdbool.h>")
        lines.append("#include <stddef.h>")
        lines.append("")
        lines.append("/*")
        lines.append(" * FeLangKit Runtime C ABI")
        lines.append(" * Auto-generated from RuntimeABISpec v\(version)")
        lines.append(" *")
        lines.append(" * This header is the canonical reference for compiler backends.")
        lines.append(" * Do NOT edit manually; regenerate from the spec instead.")
        lines.append(" */")
        lines.append("")
        lines.append("#ifdef __cplusplus")
        lines.append("extern \"C\" {")
        lines.append("#endif")
        lines.append("")

        var currentSection = ""
        for spec in functions {
            let section = sectionName(for: spec.name)
            if section != currentSection {
                if !currentSection.isEmpty {
                    lines.append("")
                }
                lines.append("/* --- \(section) --- */")
                lines.append("")
                currentSection = section
            }

            lines.append("/** \(spec.description) */")
            lines.append(spec.cDeclaration)
            lines.append("")
        }

        lines.append("#ifdef __cplusplus")
        lines.append("}")
        lines.append("#endif")
        lines.append("")
        lines.append("#endif /* FELANG_RUNTIME_ABI_H */")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    private static func sectionName(for functionName: String) -> String {
        if functionName.hasPrefix("kk_alloc")
            || functionName.hasPrefix("kk_realloc")
            || functionName.hasPrefix("kk_free")
            || functionName.hasPrefix("kk_retain")
            || functionName.hasPrefix("kk_release") {
            return "Memory Management"
        } else if functionName.hasPrefix("kk_value_get") {
            return "Value Access"
        } else if functionName.hasPrefix("kk_value") {
            return "Value Creation"
        } else if functionName.hasPrefix("kk_print")
                    || functionName.hasPrefix("kk_println")
                    || functionName.hasPrefix("kk_input") {
            return "I/O"
        } else if functionName.hasPrefix("kk_array") {
            return "Array"
        } else if functionName.hasPrefix("kk_env") {
            return "Environment"
        }
        return "Other"
    }
}
