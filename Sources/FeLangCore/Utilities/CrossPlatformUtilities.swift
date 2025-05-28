import Foundation
#if canImport(CoreFoundation)
import CoreFoundation
#endif

// MARK: - Cross-platform time utilities

/// Cross-platform time function that works on both macOS and Linux
public func getCurrentTime() -> TimeInterval {
    #if canImport(CoreFoundation)
    return CFAbsoluteTimeGetCurrent()
    #else
    return Date().timeIntervalSince1970
    #endif
}