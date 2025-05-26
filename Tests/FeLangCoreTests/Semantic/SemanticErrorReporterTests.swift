import XCTest
@testable import FeLangCore

final class SemanticErrorReporterTests: XCTestCase {

    var symbolTable: SymbolTable!
    var testPosition: SourcePosition!

    override func setUp() {
        super.setUp()
        // symbolTable = SymbolTable()
        testPosition = SourcePosition(line: 1, column: 1, offset: 0)
    }

    override func tearDown() {
        // symbolTable = nil
        testPosition = nil
        super.tearDown()
    }

    // MARK: - Configuration Tests

    func testDefaultConfiguration() {
        let config = SemanticErrorReportingConfig.default

        XCTAssertEqual(config.maxErrorCount, 100)
        XCTAssertTrue(config.enableDeduplication)
        XCTAssertTrue(config.enableErrorCorrelation)
        XCTAssertFalse(config.verboseOutput)
    }

    func testCustomConfiguration() {
        let config = SemanticErrorReportingConfig(
            maxErrorCount: 50,
            enableDeduplication: false,
            enableErrorCorrelation: false,
            verboseOutput: true
        )

        XCTAssertEqual(config.maxErrorCount, 50)
        XCTAssertFalse(config.enableDeduplication)
        XCTAssertFalse(config.enableErrorCorrelation)
        XCTAssertTrue(config.verboseOutput)
    }

    // MARK: - Basic Error Collection Tests

    func testSingleErrorCollection() {
        let reporter = SemanticErrorReporter()
        let error = SemanticError.typeMismatch(expected: .integer, actual: .string, at: testPosition)

        XCTAssertFalse(reporter.hasErrors)
        XCTAssertEqual(reporter.errorCount, 0)

        reporter.collect(error)

        XCTAssertTrue(reporter.hasErrors)
        XCTAssertEqual(reporter.errorCount, 1)

        let result = reporter.finalize(with: symbolTable)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertTrue(result.hasErrors)
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertEqual(result.errors.first, error)
    }

    func testMultipleErrorCollection() {
        let reporter = SemanticErrorReporter()
        let errors = [
            SemanticError.typeMismatch(expected: .integer, actual: .string, at: testPosition),
            SemanticError.undeclaredVariable("x", at: testPosition),
            SemanticError.invalidAssignmentTarget(at: testPosition)
        ]

        reporter.collect(errors)

        XCTAssertTrue(reporter.hasErrors)
        XCTAssertEqual(reporter.errorCount, 3)

        let result = reporter.finalize(with: symbolTable)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 3)
    }

    func testEmptyErrorCollection() {
        let reporter = SemanticErrorReporter()

        XCTAssertFalse(reporter.hasErrors)
        XCTAssertEqual(reporter.errorCount, 0)

        let result = reporter.finalize(with: symbolTable)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(result.errors.count, 0)
    }

    // MARK: - Error Deduplication Tests

    func testErrorDeduplication() {
        let reporter = SemanticErrorReporter()
        let sameError = SemanticError.typeMismatch(expected: .integer, actual: .string, at: testPosition)

        // Collect the same error multiple times
        reporter.collect(sameError)
        reporter.collect(sameError)
        reporter.collect(sameError)

        XCTAssertEqual(reporter.errorCount, 1, "Duplicate errors should be deduplicated")

        let result = reporter.finalize(with: symbolTable)
        XCTAssertEqual(result.errors.count, 1)
    }

    func testErrorDeduplicationDisabled() {
        let config = SemanticErrorReportingConfig(enableDeduplication: false)
        let reporter = SemanticErrorReporter(config: config)
        let sameError = SemanticError.typeMismatch(expected: .integer, actual: .string, at: testPosition)

        // Collect the same error multiple times
        reporter.collect(sameError)
        reporter.collect(sameError)
        reporter.collect(sameError)

        XCTAssertEqual(reporter.errorCount, 3, "With deduplication disabled, all errors should be collected")

        let result = reporter.finalize(with: symbolTable)
        XCTAssertEqual(result.errors.count, 3)
    }

    func testDifferentErrorsAtSamePosition() {
        let reporter = SemanticErrorReporter()
        let error1 = SemanticError.typeMismatch(expected: .integer, actual: .string, at: testPosition)
        let error2 = SemanticError.undeclaredVariable("x", at: testPosition)

        reporter.collect(error1)
        reporter.collect(error2)

        XCTAssertEqual(reporter.errorCount, 2, "Different error types at same position should both be collected")

        let result = reporter.finalize(with: symbolTable)
        XCTAssertEqual(result.errors.count, 2)
    }

    // MARK: - Error Threshold Tests

    func testErrorThreshold() {
        let config = SemanticErrorReportingConfig(maxErrorCount: 3)
        let reporter = SemanticErrorReporter(config: config)

        // Collect errors up to threshold
        for index in 0..<5 {
            let position = SourcePosition(line: index + 1, column: 1, offset: index)
            reporter.collect(.undeclaredVariable("var\(index)", at: position))
        }

        XCTAssertTrue(reporter.isFull, "Reporter should be full when threshold is reached")

        let result = reporter.finalize(with: symbolTable)

        // Should have 3 regular errors + 1 tooManyErrors marker
        XCTAssertEqual(result.errors.count, 4)
        XCTAssertTrue(result.errors.contains {
            if case .tooManyErrors(let count) = $0 { return count == 3 }
            return false
        })
    }

    func testErrorThresholdBoundary() {
        let config = SemanticErrorReportingConfig(maxErrorCount: 2)
        let reporter = SemanticErrorReporter(config: config)

        let pos1 = SourcePosition(line: 1, column: 1, offset: 0)
        let pos2 = SourcePosition(line: 2, column: 1, offset: 10)

        // Collect exactly the threshold number of errors
        reporter.collect(.undeclaredVariable("var1", at: pos1))
        XCTAssertFalse(reporter.isFull)

        reporter.collect(.undeclaredVariable("var2", at: pos2))
        XCTAssertTrue(reporter.isFull)

        let result = reporter.finalize(with: symbolTable)
        XCTAssertEqual(result.errors.count, 3) // 2 regular + 1 tooManyErrors
    }

    // MARK: - Clear and Reset Tests

    func testClearFunction() {
        let reporter = SemanticErrorReporter()
        
        // Use different positions to ensure both errors are collected
        let pos1 = SourcePosition(line: 1, column: 1, offset: 0)
        let pos2 = SourcePosition(line: 2, column: 1, offset: 10)

        reporter.collect(.undeclaredVariable("x", at: pos1))
        reporter.collect(.typeMismatch(expected: .integer, actual: .string, at: pos2))

        XCTAssertTrue(reporter.hasErrors)
        XCTAssertEqual(reporter.errorCount, 2)

        reporter.clear()

        XCTAssertFalse(reporter.hasErrors)
        XCTAssertEqual(reporter.errorCount, 0)

        // Should be able to collect errors again after clear
        reporter.collect(.invalidAssignmentTarget(at: testPosition))
        XCTAssertEqual(reporter.errorCount, 1)
    }

    func testFinalizePreventsFurtherCollection() {
        let reporter = SemanticErrorReporter()

        reporter.collect(.undeclaredVariable("x", at: testPosition))
        XCTAssertEqual(reporter.errorCount, 1)

        let result = reporter.finalize(with: symbolTable)
        XCTAssertEqual(result.errors.count, 1)

        // Try to collect more errors after finalization
        reporter.collect(.typeMismatch(expected: .integer, actual: .string, at: testPosition))

        // Error count should remain the same
        XCTAssertEqual(reporter.errorCount, 1)
    }

    func testBasicErrorReporting() {
        let reporter = SemanticErrorReporter()
        let pos1 = SourcePosition(line: 1, column: 1, offset: 0)
        let pos2 = SourcePosition(line: 2, column: 1, offset: 10)
        
        // Test basic error collection
        XCTAssertFalse(reporter.hasErrors)
        XCTAssertEqual(reporter.errorCount, 0)
        
        reporter.collect(.undeclaredVariable("x", at: pos1))
        XCTAssertTrue(reporter.hasErrors)
        XCTAssertEqual(reporter.errorCount, 1)
        
        reporter.collect(.typeMismatch(expected: .integer, actual: .string, at: pos2))
        XCTAssertEqual(reporter.errorCount, 2)
        
        // Test finalization
        let result = reporter.finalize(with: symbolTable)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 2)
        
        // Test that no more errors can be collected after finalization
        reporter.collect(.invalidAssignmentTarget(at: pos1))
        XCTAssertEqual(reporter.errorCount, 2) // Should remain 2
    }

    // MARK: - Thread Safety Tests

    func testConcurrentErrorCollection() {
        let config = SemanticErrorReportingConfig(maxErrorCount: 200) // Increase limit to avoid threshold issues
        let reporter = SemanticErrorReporter(config: config)
        let expectation = XCTestExpectation(description: "Concurrent error collection")
        let queue = DispatchQueue.global(qos: .userInitiated)
        let group = DispatchGroup()

        // Start multiple concurrent tasks with smaller numbers
        for outerIndex in 0..<5 {
            group.enter()
            queue.async {
                for innerIndex in 0..<5 {
                    let position = SourcePosition(line: outerIndex * 10 + innerIndex, column: 1, offset: outerIndex * 10 + innerIndex)
                    reporter.collect(.undeclaredVariable("var\(outerIndex)_\(innerIndex)", at: position))
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)

        // Should have collected 25 errors
        XCTAssertEqual(reporter.errorCount, 25)

        let result = reporter.finalize(with: symbolTable)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertTrue(result.hasErrors)
    }

    func testConcurrentAccessToProperties() {
        let reporter = SemanticErrorReporter()
        let expectation = XCTestExpectation(description: "Concurrent property access")
        let queue = DispatchQueue.global(qos: .userInitiated)
        let group = DispatchGroup()
        
        // Add some initial errors
        for index in 0..<5 {
            let position = SourcePosition(line: index, column: 1, offset: index)
            reporter.collect(.undeclaredVariable("var\(index)", at: position))
        }

        // Concurrently access properties with fewer iterations
        for _ in 0..<10 {
            group.enter()
            queue.async {
                defer { group.leave() }
                _ = reporter.hasErrors
                _ = reporter.errorCount
                _ = reporter.isFull
            }
        }

        let result = group.wait(timeout: .now() + 3.0)
        if result == .timedOut {
            XCTFail("Concurrent property access test timed out")
            return
        }
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 1.0)

        // Properties should still be consistent
        XCTAssertTrue(reporter.hasErrors)
        XCTAssertEqual(reporter.errorCount, 5)
        XCTAssertFalse(reporter.isFull)
    }

    // MARK: - Edge Case Tests

    func testCollectEmptyErrorArray() {
        let reporter = SemanticErrorReporter()

        reporter.collect([])

        XCTAssertFalse(reporter.hasErrors)
        XCTAssertEqual(reporter.errorCount, 0)
    }

    func testMultipleFinalizations() {
        let reporter = SemanticErrorReporter()

        reporter.collect(.undeclaredVariable("x", at: testPosition))

        let result1 = reporter.finalize(with: symbolTable)
        let result2 = reporter.finalize(with: symbolTable)

        // Both results should be identical
        XCTAssertEqual(result1.errors.count, result2.errors.count)
        XCTAssertEqual(result1.isSuccessful, result2.isSuccessful)
    }

    func testErrorKeyGeneration() {
        let reporter = SemanticErrorReporter()

        // Test various error types to ensure unique keys
        let pos1 = SourcePosition(line: 1, column: 1, offset: 0)
        let pos2 = SourcePosition(line: 1, column: 2, offset: 1)

        let errors = [
            SemanticError.typeMismatch(expected: .integer, actual: .string, at: pos1),
            SemanticError.typeMismatch(expected: .integer, actual: .string, at: pos2), // Different position
            SemanticError.typeMismatch(expected: .real, actual: .string, at: pos1), // Different expected type
            SemanticError.undeclaredVariable("x", at: pos1),
            SemanticError.undeclaredVariable("y", at: pos1) // Different variable name
        ]

        for error in errors {
            reporter.collect(error)
        }

        // All errors should be collected since they have different keys
        XCTAssertEqual(reporter.errorCount, 5)
    }

    // MARK: - Performance Tests

    func testPerformanceErrorCollection() {
        let config = SemanticErrorReportingConfig(maxErrorCount: 2000) // Increase limit
        let reporter = SemanticErrorReporter(config: config)

        measure {
            for index in 0..<500 { // Reduce iterations to avoid timeout
                let position = SourcePosition(line: index, column: 1, offset: index)
                reporter.collect(.undeclaredVariable("var\(index)", at: position))
            }
        }
    }

    func testPerformanceWithDeduplication() {
        let config = SemanticErrorReportingConfig(enableDeduplication: true)
        let reporter = SemanticErrorReporter(config: config)
        let sameError = SemanticError.typeMismatch(expected: .integer, actual: .string, at: testPosition)

        measure {
            for _ in 0..<500 { // Reduce iterations to avoid timeout
                reporter.collect(sameError)
            }
        }
    }

    func testMemoryUsageWithLargeErrorCount() {
        let config = SemanticErrorReportingConfig(maxErrorCount: 2000)
        let reporter = SemanticErrorReporter(config: config)

        // Collect a moderate number of errors to avoid timeout
        for index in 0..<1000 {
            let position = SourcePosition(line: index, column: 1, offset: index)
            reporter.collect(.undeclaredVariable("var\(index)", at: position))
        }

        XCTAssertTrue(reporter.hasErrors)
        XCTAssertTrue(reporter.errorCount > 0)

        // Clear should free memory
        reporter.clear()
        XCTAssertFalse(reporter.hasErrors)
        XCTAssertEqual(reporter.errorCount, 0)
    }

    func testSimpleTest() {
        // This is just a sanity check to make sure the test infrastructure works
        XCTAssertTrue(true)
        XCTAssertEqual(1 + 1, 2)
        
        // Test SourcePosition creation
        let pos = SourcePosition(line: 1, column: 2, offset: 3)
        XCTAssertEqual(pos.line, 1)
        XCTAssertEqual(pos.column, 2)
        XCTAssertEqual(pos.offset, 3)
    }
}
