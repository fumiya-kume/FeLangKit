import Foundation

/// Unicode normalizer for FE language processing
/// Implements comprehensive Unicode normalization for Japanese text processing
/// including NFC normalization, full-width to half-width conversion, and combining character handling
public struct UnicodeNormalizer {
    
    // MARK: - Statistics
    
    public struct NormalizationStats {
        public let originalLength: Int
        public let normalizedLength: Int
        public let nfcNormalizations: Int
        public let fullwidthConversions: Int
        public let japaneseNormalizations: Int
        
        public var compressionRatio: Double {
            guard originalLength > 0 else { return 1.0 }
            return Double(normalizedLength) / Double(originalLength)
        }
    }
    
    private var stats = NormalizationStats(
        originalLength: 0,
        normalizedLength: 0,
        nfcNormalizations: 0,
        fullwidthConversions: 0,
        japaneseNormalizations: 0
    )
    
    public init() {}
    
    // MARK: - Main Normalization Methods
    
    /// Normalizes text for FE language processing
    /// Applies NFC normalization, full-width to half-width conversion, and Japanese character normalization
    public static func normalizeForFE(_ input: String) -> String {
        // Step 1: NFC normalization for consistent character representation
        let nfcNormalized = input.precomposedStringWithCanonicalMapping
        
        // Step 2: Selective full-width to half-width conversion (only ASCII characters)
        let halfwidthConverted = normalizeFullWidthASCII(nfcNormalized)
        
        // Step 3: Japanese character normalization
        let japaneseNormalized = normalizeJapaneseCharacters(halfwidthConverted)
        
        return japaneseNormalized
    }
    
    /// Normalizes only full-width ASCII characters to half-width, preserving Japanese characters
    private static func normalizeFullWidthASCII(_ input: String) -> String {
        var result = ""
        
        for scalar in input.unicodeScalars {
            if scalar.value >= 0xFF01 && scalar.value <= 0xFF5E {
                // Full-width ASCII: map to half-width equivalent
                let halfWidth = UnicodeScalar(scalar.value - 0xFF01 + 0x21)!
                result.append(String(halfWidth))
            } else {
                // Keep all other characters as-is (including Japanese spaces, etc.)
                result.append(String(scalar))
            }
        }
        
        return result
    }
    
    /// Gets the current normalization statistics
    public func getStats() -> NormalizationStats {
        return stats
    }
    
    /// Resets the normalization statistics
    public mutating func resetStats() {
        stats = NormalizationStats(
            originalLength: 0,
            normalizedLength: 0,
            nfcNormalizations: 0,
            fullwidthConversions: 0,
            japaneseNormalizations: 0
        )
    }
    
    // MARK: - Japanese Character Normalization
    
    /// Normalizes Japanese-specific character variants
    private static func normalizeJapaneseCharacters(_ input: String) -> String {
        var result = input
        
        // Only normalize specific punctuation variants that are commonly confused
        // Do NOT normalize regular Japanese characters like ー or quotation marks
        
        // Special case: hiragana vu (ゔ) should become katakana vu (ヴ) for consistency
        result = result.replacingOccurrences(of: "ゔ", with: "ヴ") // U+3094 -> U+30F4
        
        // Normalize wave dash variants (commonly confused in Japanese text)  
        result = result.replacingOccurrences(of: "〜", with: "～") // U+301C -> U+FF5E
        
        // Normalize minus sign variants  
        result = result.replacingOccurrences(of: "−", with: "-") // U+2212 -> U+002D
        result = result.replacingOccurrences(of: "－", with: "-") // U+FF0D -> U+002D
        
        // Normalize dash variants
        result = result.replacingOccurrences(of: "―", with: "—") // U+2015 -> U+2014 (em dash)
        
        return result
    }
    
    // MARK: - Individual Normalization Steps
    
    /// Applies only NFC normalization
    public func normalizeNFC(_ input: String) -> String {
        return input.precomposedStringWithCanonicalMapping
    }
    
    /// Applies only full-width to half-width conversion
    public func normalizeFullwidth(_ input: String) -> String {
        return input.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? input
    }
    
    /// Applies only Japanese character normalization
    public func normalizeJapanese(_ input: String) -> String {
        return UnicodeNormalizer.normalizeJapaneseCharacters(input)
    }
    
    // MARK: - Analysis and Comparison Methods
    
    /// Analyzes normalization changes and provides statistics
    public func analyzeNormalization(_ input: String) -> NormalizationAnalysis {
        let original = input
        
        // Count various types of normalization needed
        
        // Count actual combining characters in the original text
        let combiningCharacters = original.unicodeScalars.filter { scalar in
            // Combining diacritical marks range
            return (scalar.value >= 0x0300 && scalar.value <= 0x036F) ||
                   (scalar.value >= 0x3099 && scalar.value <= 0x309A) // Japanese combining marks
        }.count
        
        // Count full-width characters
        let fullwidthCharacters = original.unicodeScalars.filter { scalar in
            // Full-width ASCII range: U+FF01 to U+FF5E
            return scalar.value >= 0xFF01 && scalar.value <= 0xFF5E
        }.count
        
        // Count Japanese character variants that need normalization
        let japaneseVariants = ["〜", "−", "－", "―", "ゔ"].reduce(0) { count, char in
            count + original.components(separatedBy: char).count - 1
        }
        
        let normalized = UnicodeNormalizer.normalizeForFE(original)
        
        return NormalizationAnalysis(
            originalText: original,
            normalizedText: normalized,
            hasChanges: original != normalized,
            originalLength: original.count,
            normalizedLength: normalized.count,
            fullwidthCharactersConverted: fullwidthCharacters,
            combiningCharactersNormalized: combiningCharacters,
            japaneseCharactersNormalized: japaneseVariants
        )
    }
    
    /// Checks if two strings are equivalent after normalization
    public func areEquivalent(_ string1: String, _ string2: String) -> Bool {
        let normalized1 = UnicodeNormalizer.normalizeForFE(string1)
        let normalized2 = UnicodeNormalizer.normalizeForFE(string2)
        
        return normalized1 == normalized2
    }
    
    // MARK: - Analysis Types
    
    public struct NormalizationAnalysis {
        public let originalText: String
        public let normalizedText: String
        public let hasChanges: Bool
        public let originalLength: Int
        public let normalizedLength: Int
        public let fullwidthCharactersConverted: Int
        public let combiningCharactersNormalized: Int
        public let japaneseCharactersNormalized: Int
        
        public var compressionRatio: Double {
            guard originalLength > 0 else { return 1.0 }
            return Double(normalizedLength) / Double(originalLength)
        }
        
        public var summary: String {
            if !hasChanges {
                return "No normalization changes required"
            }
            
            var changes: [String] = []
            if fullwidthCharactersConverted > 0 {
                changes.append("\(fullwidthCharactersConverted) full-width conversions")
            }
            if combiningCharactersNormalized > 0 {
                changes.append("\(combiningCharactersNormalized) NFC normalizations")
            }
            if japaneseCharactersNormalized > 0 {
                changes.append("\(japaneseCharactersNormalized) Japanese normalizations")
            }
            
            return "Applied: " + changes.joined(separator: ", ")
        }
    }
}

// MARK: - String Extension

extension String {
    /// Convenience method for FE language normalization
    public var normalizedForFE: String {
        return UnicodeNormalizer.normalizeForFE(self)
    }
    
    /// Convenience method for NFC normalization only
    public var normalizedNFC: String {
        let normalizer = UnicodeNormalizer()
        return normalizer.normalizeNFC(self)
    }
    
    /// Convenience method for full-width to half-width conversion only
    public var normalizedFullwidth: String {
        let normalizer = UnicodeNormalizer()
        return normalizer.normalizeFullwidth(self)
    }
    
    /// Convenience method for Japanese character normalization only
    public var normalizedJapanese: String {
        let normalizer = UnicodeNormalizer()
        return normalizer.normalizeJapanese(self)
    }
} 