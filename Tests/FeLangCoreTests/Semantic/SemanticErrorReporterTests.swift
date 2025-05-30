import Testing
@testable import FeLangCore

@Suite("SemanticErrorReporter Tests")
struct SemanticErrorReporterTests {

    // MARK: - Basic Error Collection Tests

    @Test func collectSingleError() {
        let symbolTable = SymbolTable()
        let sourcePosition = SourcePosition(line: 1, column: 1, offset: 0)
        let reporter = SemanticErrorReporter()
        let error = SemanticError.undeclaredVariable("x", position: sourcePosition)

        reporter.collect(error)

        #expect(reporter.errorCount == 1)
        #expect(reporter.warningCount == 0)
        #expect(!reporter.hasReachedErrorLimit)

        let result = reporter.finalize(with: symbolTable)
        #expect(!result.isSuccessful)
        #expect(result.errors.count == 1)
        #expect(result.errors[0] == error)
    }

    @Test func collectMultipleErrors() {
        let symbolTable = SymbolTable()
        let sourcePosition = SourcePosition(line: 1, column: 1, offset: 0)
        let reporter = SemanticErrorReporter()
        let errors = [
            SemanticError.undeclaredVariable("x", position: sourcePosition),
            SemanticError.undeclaredVariable("y", position: SourcePosition(line: 2, column: 1, offset: 10)),
            SemanticError.typeMismatch(expected: .integer, actual: .string, position: SourcePosition(line: 3, column: 1, offset: 20))
        ]

        reporter.collect(errors)

        #expect(reporter.errorCount == 3)

        let result = reporter.finalize(with: symbolTable)
        #expect(!result.isSuccessful)
        #expect(result.errors.count == 3)
    }

    @Test func collectSingleWarning() {
        let symbolTable = SymbolTable()
        let sourcePosition = SourcePosition(line: 1, column: 1, offset: 0)
        let reporter = SemanticErrorReporter()
        let warning = SemanticWarning.unusedVariable("x", position: sourcePosition)

        reporter.collect(warning)

        #expect(reporter.errorCount == 0)
        #expect(reporter.warningCount == 1)

        let result = reporter.finalize(with: symbolTable)
        #expect(result.isSuccessful) // No errors, only warnings
        #expect(result.warnings.count == 1)
        #expect(result.warnings[0] == warning)
    }

    @Test func collectMultipleWarnings() {
        let symbolTable = SymbolTable()
        let sourcePosition = SourcePosition(line: 1, column: 1, offset: 0)
        let reporter = SemanticErrorReporter()
        let warnings = [
            SemanticWarning.unusedVariable("x", position: sourcePosition),
            SemanticWarning.unusedFunction("foo", position: SourcePosition(line: 2, column: 1, offset: 10))
        ]

        reporter.collect(warnings)

        #expect(reporter.warningCount == 2)

        let result = reporter.finalize(with: symbolTable)
        #expect(result.isSuccessful)
        #expect(result.warnings.count == 2)
    }

    // MARK: - Configuration Tests

    @Test func defaultConfiguration() {
        let config = SemanticErrorReportingConfig.default

        #expect(config.maxErrorCount == 100)
        #expect(config.enableDeduplication)
        #expect(!config.enableErrorCorrelation)
        #expect(!config.verboseOutput)
    }

    @Test func strictConfiguration() {
        let config = SemanticErrorReportingConfig.strict

        #expect(config.maxErrorCount == 1000)
        #expect(config.enableDeduplication)
        #expect(config.enableErrorCorrelation)
        #expect(config.verboseOutput)
    }

    @Test func fastConfiguration() {
        let config = SemanticErrorReportingConfig.fast

        #expect(config.maxErrorCount == 50)
        #expect(!config.enableDeduplication)
        #expect(!config.enableErrorCorrelation)
        #expect(!config.verboseOutput)
    }

    @Test func customConfiguration() {
        let config = SemanticErrorReportingConfig(
            maxErrorCount: 25,
            enableDeduplication: true,
            enableErrorCorrelation: true,
            verboseOutput: false
        )

        #expect(config.maxErrorCount == 25)
        #expect(config.enableDeduplication)
        #expect(config.enableErrorCorrelation)
        #expect(!config.verboseOutput)
    }

    // MARK: - Error Deduplication Tests

    @Test func errorDeduplicationEnabled() {
        let symbolTable = SymbolTable()
        let sourcePosition = SourcePosition(line: 1, column: 1, offset: 0)
        let config = SemanticErrorReportingConfig(enableDeduplication: true)
        let reporter = SemanticErrorReporter(config: config)

        // Same error at same position should be deduplicated
        let error1 = SemanticError.undeclaredVariable("x", position: sourcePosition)
        let error2 = SemanticError.undeclaredVariable("y", position: sourcePosition) // Different variable, same position

        reporter.collect(error1)
        reporter.collect(error2)

        #expect(reporter.errorCount == 1) // Should only have one error due to deduplication

        let result = reporter.finalize(with: symbolTable)
        #expect(result.errors.count == 1)
    }

    @Test func errorDeduplicationDisabled() {
        let symbolTable = SymbolTable()
        let sourcePosition = SourcePosition(line: 1, column: 1, offset: 0)
        let config = SemanticErrorReportingConfig(enableDeduplication: false)
        let reporter = SemanticErrorReporter(config: config)

        // Same position, different errors
        let error1 = SemanticError.undeclaredVariable("x", position: sourcePosition)
        let error2 = SemanticError.undeclaredVariable("y", position: sourcePosition)

        reporter.collect(error1)
        reporter.collect(error2)

        #expect(reporter.errorCount == 2) // Should have both errors

        let result = reporter.finalize(with: symbolTable)
        #expect(result.errors.count == 2)
    }

    @Test func errorDeduplicationDifferentPositions() {
        let symbolTable = SymbolTable()
        let config = SemanticErrorReportingConfig(enableDeduplication: true)
        let reporter = SemanticErrorReporter(config: config)

        let pos1 = SourcePosition(line: 1, column: 1, offset: 0)
        let pos2 = SourcePosition(line: 2, column: 1, offset: 10)

        let error1 = SemanticError.undeclaredVariable("x", position: pos1)
        let error2 = SemanticError.undeclaredVariable("x", position: pos2)

        reporter.collect(error1)
        reporter.collect(error2)

        #expect(reporter.errorCount == 2) // Different positions, should not deduplicate

        let result = reporter.finalize(with: symbolTable)
        #expect(result.errors.count == 2)
    }

    // MARK: - Error Limit Tests

    @Test func errorLimit() {
        let symbolTable = SymbolTable()
        let config = SemanticErrorReportingConfig(maxErrorCount: 3)
        let reporter = SemanticErrorReporter(config: config)

        for index in 1...5 {
            let error = SemanticError.undeclaredVariable("var\(index)", position: SourcePosition(line: index, column: 1, offset: index * 10))
            reporter.collect(error)
        }

        #expect(reporter.errorCount == 4) // 3 regular errors + 1 "too many errors" error
        #expect(reporter.hasReachedErrorLimit)

        let result = reporter.finalize(with: symbolTable)
        #expect(result.errors.count == 4)

        // Check that the last error is the "too many errors" error
        let lastError = result.errors.last
        #expect(lastError != nil)
        if case .tooManyErrors(let count) = lastError! {
            #expect(count == 3)
        } else {
            #expect(Bool(false), "Expected tooManyErrors error")
        }
    }

    @Test func errorLimitWithZeroMax() {
        let symbolTable = SymbolTable()
        let sourcePosition = SourcePosition(line: 1, column: 1, offset: 0)
        let config = SemanticErrorReportingConfig(maxErrorCount: 0)
        let reporter = SemanticErrorReporter(config: config)

        let error = SemanticError.undeclaredVariable("x", position: sourcePosition)
        reporter.collect(error)

        #expect(reporter.errorCount == 1) // Should add "too many errors" error immediately
        #expect(reporter.hasReachedErrorLimit)

        let result = reporter.finalize(with: symbolTable)
        if case .tooManyErrors(let count) = result.errors.first! {
            #expect(isEmpty)
        } else {
            #expect(Bool(false), "Expected tooManyErrors error")
        }
    }

    // MARK: - Error Correlation Tests

    @Test func errorCorrelationEnabled() throws {
        let symbolTable = SymbolTable()
        let sourcePosition = SourcePosition(line: 1, column: 1, offset: 0)
        // Add unused variables to symbol table
        _ = symbolTable.declare(name: "unusedVar", type: .integer, kind: .variable, position: sourcePosition)
        _ = symbolTable.declare(name: "unusedFunc", type: .function(parameters: [], returnType: .integer), kind: .function, position: SourcePosition(line: 2, column: 1, offset: 10))

        let config = SemanticErrorReportingConfig(enableErrorCorrelation: true)
        let reporter = SemanticErrorReporter(config: config)

        let result = reporter.finalize(with: symbolTable)

        // Should generate warnings for unused symbols
        // Note: SymbolTable.getUnusedSymbols() excludes functions by design, so we only expect the variable
        #expect(result.warnings.count == 1)

        let warningTypes = result.warnings.map { warning in
            switch warning {
            case .unusedVariable(let name, _):
                return "unusedVariable:\(name)"
            case .unusedFunction(let name, _):
                return "unusedFunction:\(name)"
            default:
                return "other"
            }
        }

        #expect(warningTypes.contains("unusedVariable:unusedVar"))
    }

    @Test func errorCorrelationDisabled() throws {
        let symbolTable = SymbolTable()
        let sourcePosition = SourcePosition(line: 1, column: 1, offset: 0)
        // Add unused variables to symbol table
        _ = symbolTable.declare(name: "unusedVar", type: .integer, kind: .variable, position: sourcePosition)

        let config = SemanticErrorReportingConfig(enableErrorCorrelation: false)
        let reporter = SemanticErrorReporter(config: config)

        let result = reporter.finalize(with: symbolTable)

        // Should not generate warnings for unused symbols
        #expect(result.warnings.isEmpty)
    }

    // MARK: - Finalization Tests

    @Test func finalizationPreventsMoreCollections() {
        let symbolTable = SymbolTable()
        let sourcePosition = SourcePosition(line: 1, column: 1, offset: 0)
        let reporter = SemanticErrorReporter()
        let error1 = SemanticError.undeclaredVariable("x", position: sourcePosition)
        let error2 = SemanticError.undeclaredVariable("y", position: SourcePosition(line: 2, column: 1, offset: 10))

        reporter.collect(error1)
        let result1 = reporter.finalize(with: symbolTable)

        // Try to collect another error after finalization
        reporter.collect(error2)
        let result2 = reporter.finalize(with: symbolTable)

        #expect(result1.errors.count == 1)
        #expect(result2.errors.count == 1) // Should be the same as first result
        #expect(reporter.errorCount == 1) // Should not increase
    }

    @Test func multipleFinalizationCalls() {
        let symbolTable = SymbolTable()
        let sourcePosition = SourcePosition(line: 1, column: 1, offset: 0)
        let reporter = SemanticErrorReporter()
        let error = SemanticError.undeclaredVariable("x", position: sourcePosition)

        reporter.collect(error)

        let result1 = reporter.finalize(with: symbolTable)
        let result2 = reporter.finalize(with: symbolTable)

        #expect(result1.errors.count == 1)
        #expect(result2.errors.count == 1)
        #expect(result1.errors == result2.errors)
    }

    // MARK: - Reset Functionality Tests

    @Test func reset() {
        let symbolTable = SymbolTable()
        let sourcePosition = SourcePosition(line: 1, column: 1, offset: 0)
        let reporter = SemanticErrorReporter()
        let error = SemanticError.undeclaredVariable("x", position: sourcePosition)
        let warning = SemanticWarning.unusedVariable("y", position: sourcePosition)

        reporter.collect(error)
        reporter.collect(warning)

        #expect(reporter.errorCount == 1)
        #expect(reporter.warningCount == 1)

        reporter.reset()

        #expect(reporter.errorCount == 0)
        #expect(reporter.warningCount == 0)
        #expect(!reporter.hasReachedErrorLimit)

        // Should be able to collect new errors after reset
        reporter.collect(error)
        #expect(reporter.errorCount == 1)

        let result = reporter.finalize(with: symbolTable)
        #expect(result.errors.count == 1)
    }

    @Test func resetAfterFinalization() {
        let symbolTable = SymbolTable()
        let sourcePosition = SourcePosition(line: 1, column: 1, offset: 0)
        let reporter = SemanticErrorReporter()
        let error = SemanticError.undeclaredVariable("x", position: sourcePosition)

        reporter.collect(error)
        _ = reporter.finalize(with: symbolTable)

        reporter.reset()

        // Should be able to collect new errors after reset
        let newError = SemanticError.undeclaredVariable("z", position: SourcePosition(line: 3, column: 1, offset: 20))
        reporter.collect(newError)

        #expect(reporter.errorCount == 1)

        let result = reporter.finalize(with: symbolTable)
        #expect(result.errors.count == 1)
        #expect(result.errors[0] == newError)
    }

    // MARK: - Thread Safety Tests

    @Test func concurrentErrorCollection() async {
        let reporter = SemanticErrorReporter()
        let errorCount = 100

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<errorCount {
                group.addTask {
                    let position = SourcePosition(line: index + 1, column: 1, offset: index * 10)
                    let error = SemanticError.undeclaredVariable("var\(index)", position: position)
                    reporter.collect(error)
                }
            }
        }

        #expect(reporter.errorCount == errorCount)
    }

    @Test func concurrentWarningCollection() async {
        let reporter = SemanticErrorReporter()
        let warningCount = 50

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<warningCount {
                group.addTask {
                    let position = SourcePosition(line: index + 1, column: 1, offset: index * 10)
                    let warning = SemanticWarning.unusedVariable("var\(index)", position: position)
                    reporter.collect(warning)
                }
            }
        }

        #expect(reporter.warningCount == warningCount)
    }

    // MARK: - Edge Case Tests

    @Test func emptyErrorCollection() {
        let symbolTable = SymbolTable()
        let reporter = SemanticErrorReporter()

        #expect(reporter.errorCount == 0)
        #expect(reporter.warningCount == 0)
        #expect(!reporter.hasReachedErrorLimit)

        let result = reporter.finalize(with: symbolTable)
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
        #expect(result.warnings.isEmpty)
    }

    @Test func tooManyErrorsDeduplication() {
        let symbolTable = SymbolTable()
        let sourcePosition = SourcePosition(line: 1, column: 1, offset: 0)
        let config = SemanticErrorReportingConfig(maxErrorCount: 1, enableDeduplication: true)
        let reporter = SemanticErrorReporter(config: config)

        // Add multiple errors at same position to trigger both deduplication and limit
        let error1 = SemanticError.undeclaredVariable("x", position: sourcePosition)
        let error2 = SemanticError.undeclaredVariable("y", position: sourcePosition)
        let error3 = SemanticError.undeclaredVariable("z", position: SourcePosition(line: 2, column: 1, offset: 10))

        reporter.collect(error1)
        reporter.collect(error2) // Should be deduplicated
        reporter.collect(error3) // Should trigger limit

        #expect(reporter.errorCount == 2) // 1 regular error + 1 "too many errors" error

        let result = reporter.finalize(with: symbolTable)
        #expect(result.errors.count == 2)
    }
}
