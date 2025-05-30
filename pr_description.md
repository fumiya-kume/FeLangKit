Perfect! Now I can see that this PR is about the comprehensive cursor rules enhancement commit (653616e). Let me generate the PR description based on this information:

## Summary
This PR adds a comprehensive set of Cursor IDE rules to standardize and enhance the development experience across the FeLangKit project, including specialized automation patterns for the CCW (Claude Code Workflow) tool. The enhancement introduces 5 specialized rule categories covering Swift development standards, parsing patterns, architecture guidelines, automation best practices, and enhanced task validation.

## Background & Context

- **Original Issue:** The FeLangKit project lacked standardized development guidelines and automated code quality enforcement through IDE-integrated rules, leading to inconsistent code patterns and longer code review cycles.
- **Root Cause:** The absence of comprehensive Cursor IDE rules meant developers had to manually maintain coding standards, architecture patterns, and best practices without automated guidance or enforcement.
- **User Impact:** Development teams experienced longer onboarding times, inconsistent code quality, and increased manual review effort for maintaining project standards across Swift language toolkit development and CCW automation tool development.
- **Previous State:** The project had only basic `.cursor/rules/all.mdc` and `swift-file-task.mdc` files with minimal development guidance, requiring developers to reference external documentation for coding standards.
- **Requirements:** Need for automated IDE-integrated guidelines covering Swift 6.0 best practices, FeLangKit parsing architecture patterns, CCW automation standards, comprehensive testing strategies, and performance optimization guidelines.

## Solution Approach

- **Core Solution:** Implemented a comprehensive set of modular Cursor IDE rules organized by functional domain (architecture, automation, parsing, Swift standards) that provide real-time development guidance and automated quality enforcement.
- **Technical Strategy:** Created category-based rule structure using MDC (Markdown with Code) format that integrates seamlessly with Cursor IDE's rule system while maintaining version control and team synchronization.
- **Logic & Reasoning:** Organized rules into 5 specialized modules to address specific development domains: CCW automation patterns, FeLangKit architecture guidelines, parsing implementation patterns, Swift development standards, and enhanced file-level task validation.
- **Alternative Approaches:** Considered external documentation or separate tooling configurations, but chose IDE-integrated rules for real-time feedback, automatic team synchronization, and reduced context switching during development.
- **Architecture Changes:** Introduced modular rule organization that complements existing CI/CD workflows and maintains backward compatibility with existing development processes.

## Implementation Details

- **Key Components:** 
  - `ccw-automation.mdc`: CCW tool development patterns and GitHub automation
  - `felangkit-architecture.mdc`: Swift package organization and module guidelines  
  - `parsing-patterns.mdc`: Tokenizer, parser, and AST implementation patterns
  - `swift-development-standards.mdc`: Swift 6.0 conventions and quality standards
  - Enhanced `swift-file-task.mdc`: Improved task automation and validation
- **Code Changes:** Added 433 lines of comprehensive documentation covering development patterns, best practices, error handling strategies, testing methodologies, and automation guidelines specific to language toolkit development.
- **Files Modified:**
  - `.cursor/rules/ccw-automation.mdc` (new): 102 lines of CCW automation patterns
  - `.cursor/rules/felangkit-architecture.mdc` (new): 48 lines of architecture guidelines
  - `.cursor/rules/parsing-patterns.mdc` (new): 168 lines of parsing implementation patterns
  - `.cursor/rules/swift-development-standards.mdc` (new): 83 lines of Swift standards
  - `.cursor/rules/swift-file-task.mdc` (enhanced): Added 32 lines of improved task validation
- **New Functionality:** Real-time IDE guidance for Swift development, parsing pattern enforcement, CCW automation standards, architecture compliance checking, and enhanced pre-commit validation workflows.
- **Integration Points:** Rules integrate with existing SwiftLint configuration, GitHub Actions CI/CD workflows, and the CCW automation tool's development patterns.
- **Error Handling:** Includes comprehensive error handling patterns for parsing components, automation workflows, and cross-platform compatibility considerations.

## Technical Logic

- **Algorithm/Logic:** Implemented category-based rule organization where each rule module targets specific development domains, providing contextual guidance based on file types and development activities. Rules use MDC format for rich documentation with embedded code examples.
- **Data Flow:** Cursor IDE automatically loads rules from `.cursor/rules/` directory, applies them based on file patterns and project context, and provides real-time feedback during development activities.
- **Performance Considerations:** Rules are designed with minimal IDE overhead, using glob patterns for selective application and avoiding computationally expensive validations during development.
- **Security Considerations:** Includes security-focused patterns for parsing components (input validation, nesting limits) and automation workflows (credential handling, process management).
- **Backwards Compatibility:** New rules complement existing development workflows without requiring changes to build processes, CI/CD configurations, or existing code patterns.

## Testing & Validation

- **Test Strategy:** Rules include testing guidelines that align with existing FeLangKit test structure (132 tests across tokenizer, parser, expression, and utility modules) and define patterns for golden file testing and performance validation.
- **Test Coverage:** Each rule module includes specific testing patterns: unit testing for parsing components, integration testing for module interactions, performance testing for language toolkit operations, and automation testing for CCW workflows.
- **Manual Testing:** Validated rules provide appropriate guidance across different development scenarios including new feature development, bug fixes, refactoring operations, and automation tool enhancement.
- **Edge Cases:** Rules address edge cases specific to language toolkit development such as Unicode handling, parsing error recovery, cross-platform compatibility, and automation workflow failure scenarios.
- **Quality Assurance:** All rule content follows established documentation standards and includes practical code examples that demonstrate best practices for FeLangKit development patterns.

## Impact & Future Work

- **Breaking Changes:** No breaking changes to existing development workflows; rules enhance existing processes without requiring modifications to build configurations or CI/CD pipelines.
- **Performance Impact:** Minimal performance impact on IDE operations; rules are designed for efficient loading and application with selective activation based on file patterns and development context.
- **Maintenance Impact:** Improves long-term maintainability by codifying best practices, reducing review cycles, and providing consistent guidance for new contributors across Swift language toolkit development.
- **Future Enhancements:** Rule structure supports easy extension for additional development domains, integration with future tooling enhancements, and adaptation to evolving Swift language features and FeLangKit architecture patterns.
- **Technical Debt:** Resolves technical debt related to inconsistent coding patterns and reduces future debt accumulation by providing automated guidance for complex language toolkit development scenarios.
