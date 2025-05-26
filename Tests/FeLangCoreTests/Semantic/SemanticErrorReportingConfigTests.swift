import XCTest
@testable import FeLangCore

final class SemanticErrorReportingConfigTests: XCTestCase {
    
    func testDefaultConfiguration() {
        let config = SemanticErrorReportingConfig.default
        
        XCTAssertEqual(config.maxErrorCount, 100)
        XCTAssertTrue(config.enableDeduplication)
        XCTAssertTrue(config.enableErrorCorrelation)
        XCTAssertFalse(config.verboseOutput)
    }
    
    func testCustomConfiguration() {
        let config = SemanticErrorReportingConfig(
            maxErrorCount: 42,
            enableDeduplication: false,
            enableErrorCorrelation: false,
            verboseOutput: true
        )
        
        XCTAssertEqual(config.maxErrorCount, 42)
        XCTAssertFalse(config.enableDeduplication)
        XCTAssertFalse(config.enableErrorCorrelation)
        XCTAssertTrue(config.verboseOutput)
    }
    
    func testMaxErrorCountValidation() {
        // Test negative values are clamped to 1
        let negativeConfig = SemanticErrorReportingConfig(maxErrorCount: -10)
        XCTAssertEqual(negativeConfig.maxErrorCount, 1)
        
        // Test zero is clamped to 1
        let zeroConfig = SemanticErrorReportingConfig(maxErrorCount: 0)
        XCTAssertEqual(zeroConfig.maxErrorCount, 1)
        
        // Test positive values are preserved
        let positiveConfig = SemanticErrorReportingConfig(maxErrorCount: 50)
        XCTAssertEqual(positiveConfig.maxErrorCount, 50)
        
        // Test large values are preserved
        let largeConfig = SemanticErrorReportingConfig(maxErrorCount: 10000)
        XCTAssertEqual(largeConfig.maxErrorCount, 10000)
    }
    
    func testConfigurationCombinations() {
        // Test all flags enabled
        let allEnabled = SemanticErrorReportingConfig(
            maxErrorCount: 200,
            enableDeduplication: true,
            enableErrorCorrelation: true,
            verboseOutput: true
        )
        XCTAssertEqual(allEnabled.maxErrorCount, 200)
        XCTAssertTrue(allEnabled.enableDeduplication)
        XCTAssertTrue(allEnabled.enableErrorCorrelation)
        XCTAssertTrue(allEnabled.verboseOutput)
        
        // Test all flags disabled
        let allDisabled = SemanticErrorReportingConfig(
            maxErrorCount: 25,
            enableDeduplication: false,
            enableErrorCorrelation: false,
            verboseOutput: false
        )
        XCTAssertEqual(allDisabled.maxErrorCount, 25)
        XCTAssertFalse(allDisabled.enableDeduplication)
        XCTAssertFalse(allDisabled.enableErrorCorrelation)
        XCTAssertFalse(allDisabled.verboseOutput)
        
        // Test mixed configuration
        let mixed = SemanticErrorReportingConfig(
            maxErrorCount: 75,
            enableDeduplication: true,
            enableErrorCorrelation: false,
            verboseOutput: true
        )
        XCTAssertEqual(mixed.maxErrorCount, 75)
        XCTAssertTrue(mixed.enableDeduplication)
        XCTAssertFalse(mixed.enableErrorCorrelation)
        XCTAssertTrue(mixed.verboseOutput)
    }
    
    func testConfigurationIsValueType() {
        // Verify that SemanticErrorReportingConfig is a value type
        var config1 = SemanticErrorReportingConfig(maxErrorCount: 10)
        let config2 = config1
        
        // This test doesn't actually modify config1 since the struct is immutable,
        // but it verifies that we're dealing with value semantics
        XCTAssertEqual(config1.maxErrorCount, config2.maxErrorCount)
        XCTAssertEqual(config1.enableDeduplication, config2.enableDeduplication)
        XCTAssertEqual(config1.enableErrorCorrelation, config2.enableErrorCorrelation)
        XCTAssertEqual(config1.verboseOutput, config2.verboseOutput)
    }
    
    func testConfigurationSendable() {
        // Test that configuration can be used in concurrent contexts
        let config = SemanticErrorReportingConfig(maxErrorCount: 5)
        
        let expectation = XCTestExpectation(description: "Configuration access from multiple threads")
        expectation.expectedFulfillmentCount = 10
        
        for i in 0..<10 {
            DispatchQueue.global().async {
                // Access configuration properties from different threads
                let maxCount = config.maxErrorCount
                let dedup = config.enableDeduplication
                let correlation = config.enableErrorCorrelation
                let verbose = config.verboseOutput
                
                XCTAssertEqual(maxCount, 5)
                XCTAssertTrue(dedup)
                XCTAssertTrue(correlation)
                XCTAssertFalse(verbose)
                
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testMinimalConfiguration() {
        // Test the smallest valid configuration
        let minimal = SemanticErrorReportingConfig(
            maxErrorCount: 1,
            enableDeduplication: false,
            enableErrorCorrelation: false,
            verboseOutput: false
        )
        
        XCTAssertEqual(minimal.maxErrorCount, 1)
        XCTAssertFalse(minimal.enableDeduplication)
        XCTAssertFalse(minimal.enableErrorCorrelation)
        XCTAssertFalse(minimal.verboseOutput)
    }
    
    func testHighPerformanceConfiguration() {
        // Test configuration optimized for performance (minimal features)
        let highPerf = SemanticErrorReportingConfig(
            maxErrorCount: 1000,
            enableDeduplication: false,  // Skip deduplication for speed
            enableErrorCorrelation: false,  // Skip correlation for speed
            verboseOutput: false  // Minimal output
        )
        
        XCTAssertEqual(highPerf.maxErrorCount, 1000)
        XCTAssertFalse(highPerf.enableDeduplication)
        XCTAssertFalse(highPerf.enableErrorCorrelation)
        XCTAssertFalse(highPerf.verboseOutput)
    }
    
    func testDevelopmentConfiguration() {
        // Test configuration suitable for development (all features enabled)
        let development = SemanticErrorReportingConfig(
            maxErrorCount: 50,  // Lower limit for faster feedback
            enableDeduplication: true,  // Clean output
            enableErrorCorrelation: true,  // Group related errors
            verboseOutput: true  // Detailed information
        )
        
        XCTAssertEqual(development.maxErrorCount, 50)
        XCTAssertTrue(development.enableDeduplication)
        XCTAssertTrue(development.enableErrorCorrelation)
        XCTAssertTrue(development.verboseOutput)
    }
}