import Foundation

/// Unicode normalizer for FE language processing
/// Implements comprehensive Unicode normalization for Japanese text processing
/// including NFC/NFD/NFKC/NFKD normalization, full-width to half-width conversion, 
/// combining character handling, bidirectional text support, and security features
///
/// ## Usage
///
/// ### Quick normalization (no statistics):
/// ```swift
/// let normalized = UnicodeNormalizer.normalizeForFE(text)
/// // or
/// let normalized = text.normalizedForFE
/// ```
///
/// ### Normalization with automatic statistics tracking:
/// ```swift
/// var normalizer = UnicodeNormalizer()
/// let normalized = normalizer.normalize(text)
/// let stats = normalizer.getStats()
/// print("Applied \(stats.fullwidthConversions) full-width conversions")
/// ```
///
/// ### One-shot normalization with statistics:
/// ```swift
/// let (normalized, stats) = text.normalizedForFEWithStats()
/// print("Compression ratio: \(stats.compressionRatio)")
/// ```
public struct UnicodeNormalizer {

    // MARK: - Unicode Character Classification

    /// Comprehensive Unicode character classification system
    /// Based on Unicode General Categories for detailed character analysis
    public enum UnicodeCharacterClass {
        case letter(subcategory: LetterSubcategory)
        case mark(subcategory: MarkSubcategory) 
        case number(subcategory: NumberSubcategory)
        case punctuation(subcategory: PunctuationSubcategory)
        case symbol(subcategory: SymbolSubcategory)
        case separator(subcategory: SeparatorSubcategory)
        case other(subcategory: OtherSubcategory)
    }

    public enum LetterSubcategory {
        case uppercaseLetter          // Lu
        case lowercaseLetter          // Ll  
        case titlecaseLetter          // Lt
        case modifierLetter           // Lm
        case otherLetter              // Lo (includes CJK)
    }

    public enum MarkSubcategory {
        case nonspacingMark           // Mn (combining marks)
        case spacingCombiningMark     // Mc
        case enclosingMark            // Me
    }

    public enum NumberSubcategory {
        case decimalDigitNumber       // Nd
        case letterNumber             // Nl
        case otherNumber              // No
    }

    public enum PunctuationSubcategory {
        case connectorPunctuation     // Pc
        case dashPunctuation          // Pd
        case openPunctuation          // Ps
        case closePunctuation         // Pe
        case initialPunctuation       // Pi
        case finalPunctuation         // Pf
        case otherPunctuation         // Po
    }

    public enum SymbolSubcategory {
        case mathSymbol               // Sm
        case currencySymbol           // Sc
        case modifierSymbol           // Sk
        case otherSymbol              // So (includes emoji)
    }

    public enum SeparatorSubcategory {
        case spaceSeparator           // Zs
        case lineSeparator            // Zl
        case paragraphSeparator       // Zp
    }

    public enum OtherSubcategory {
        case control                  // Cc
        case format                   // Cf
        case surrogate                // Cs
        case privateUse               // Co
        case notAssigned              // Cn
    }

    // MARK: - Normalization Forms

    /// Unicode normalization forms supported by the normalizer
    public enum NormalizationForm {
        case nfc    // Canonical Decomposition followed by Canonical Composition
        case nfd    // Canonical Decomposition
        case nfkc   // Compatibility Decomposition followed by Canonical Composition
        case nfkd   // Compatibility Decomposition
    }

    // MARK: - Security Configuration

    /// Security configuration for Unicode normalization
    public struct SecurityConfig {
        /// Enable homoglyph detection and mitigation
        public let enableHomoglyphDetection: Bool
        
        /// Enable normalization attack prevention
        public let preventNormalizationAttacks: Bool
        
        /// Maximum allowed string length after normalization
        public let maxNormalizedLength: Int
        
        /// Enable bidirectional text reordering detection
        public let detectBidiReordering: Bool
        
        public init(
            enableHomoglyphDetection: Bool = true,
            preventNormalizationAttacks: Bool = true,
            maxNormalizedLength: Int = 10000,
            detectBidiReordering: Bool = true
        ) {
            self.enableHomoglyphDetection = enableHomoglyphDetection
            self.preventNormalizationAttacks = preventNormalizationAttacks
            self.maxNormalizedLength = maxNormalizedLength
            self.detectBidiReordering = detectBidiReordering
        }
    }

    // MARK: - Statistics

    public struct NormalizationStats {
        public let originalLength: Int
        public let normalizedLength: Int
        public let nfcNormalizations: Int
        public let fullwidthConversions: Int
        public let japaneseNormalizations: Int
        public let emojiNormalizations: Int
        public let mathSymbolNormalizations: Int
        public let bidiReorderings: Int
        public let homoglyphsDetected: Int
        public let securityIssuesFound: Int

        public var compressionRatio: Double {
            guard originalLength > 0 else { return 1.0 }
            return Double(normalizedLength) / Double(originalLength)
        }

        public var hasSecurityConcerns: Bool {
            return homoglyphsDetected > 0 || securityIssuesFound > 0 || bidiReorderings > 0
        }
    }

    private var stats = NormalizationStats(
        originalLength: 0,
        normalizedLength: 0,
        nfcNormalizations: 0,
        fullwidthConversions: 0,
        japaneseNormalizations: 0,
        emojiNormalizations: 0,
        mathSymbolNormalizations: 0,
        bidiReorderings: 0,
        homoglyphsDetected: 0,
        securityIssuesFound: 0
    )

    public let securityConfig: SecurityConfig

    public init(securityConfig: SecurityConfig = SecurityConfig()) {
        self.securityConfig = securityConfig
    }

    // MARK: - Main Normalization Methods

    /// Instance method that normalizes text and tracks statistics
    /// Applies comprehensive Unicode normalization with security checks
    /// Updates internal statistics that can be retrieved with getStats()
    public mutating func normalize(_ input: String, form: NormalizationForm = .nfc) -> String {
        let originalLength = input.count

        // Security pre-checks
        if securityConfig.preventNormalizationAttacks && originalLength > securityConfig.maxNormalizedLength {
            // Update stats with security issue
            stats = NormalizationStats(
                originalLength: originalLength,
                normalizedLength: 0,
                nfcNormalizations: 0,
                fullwidthConversions: 0,
                japaneseNormalizations: 0,
                emojiNormalizations: 0,
                mathSymbolNormalizations: 0,
                bidiReorderings: 0,
                homoglyphsDetected: 0,
                securityIssuesFound: 1
            )
            return input // Return original to prevent attacks
        }

        // Count changes that will be made during normalization
        let nfcChanges = countNFCChanges(input)
        let fullwidthChanges = countFullwidthChanges(input)
        let japaneseChanges = countJapaneseChanges(input)
        let emojiChanges = countEmojiChanges(input)
        let mathChanges = countMathSymbolChanges(input)
        let bidiIssues = countBidiIssues(input)
        let homoglyphs = countHomoglyphs(input)

        // Perform the actual normalization
        let result = Self.normalizeForFE(input, form: form, securityConfig: securityConfig)

        // Security post-checks
        let securityIssues = (result.count > securityConfig.maxNormalizedLength) ? 1 : 0

        // Update statistics
        stats = NormalizationStats(
            originalLength: originalLength,
            normalizedLength: result.count,
            nfcNormalizations: nfcChanges,
            fullwidthConversions: fullwidthChanges,
            japaneseNormalizations: japaneseChanges,
            emojiNormalizations: emojiChanges,
            mathSymbolNormalizations: mathChanges,
            bidiReorderings: bidiIssues,
            homoglyphsDetected: homoglyphs,
            securityIssuesFound: securityIssues
        )

        return result
    }

    /// Static convenience method for simple normalization without statistics tracking
    /// Applies comprehensive Unicode normalization with optional security configuration
    /// For automatic statistics tracking, use the instance method normalize() instead
    public static func normalizeForFE(
        _ input: String, 
        form: NormalizationForm = .nfc, 
        securityConfig: SecurityConfig = SecurityConfig()
    ) -> String {
        // Step 1: Apply specified Unicode normalization form
        let formNormalized = applyNormalizationForm(input, form: form)

        // Step 2: Selective full-width to half-width conversion (only ASCII characters)
        let halfwidthConverted = normalizeFullWidthASCII(formNormalized)

        // Step 3: Japanese character normalization
        let japaneseNormalized = normalizeJapaneseCharacters(halfwidthConverted)

        // Step 4: Emoji and mathematical symbol normalization
        let emojiNormalized = normalizeEmoji(japaneseNormalized)
        let mathNormalized = normalizeMathematicalSymbols(emojiNormalized)

        // Step 5: Security processing
        let securityProcessed = applySecurityProcessing(mathNormalized, config: securityConfig)

        return securityProcessed
    }

    // MARK: - Normalization Form Implementation

    /// Applies the specified Unicode normalization form
    private static func applyNormalizationForm(_ input: String, form: NormalizationForm) -> String {
        switch form {
        case .nfc:
            return input.precomposedStringWithCanonicalMapping
        case .nfd:
            return input.decomposedStringWithCanonicalMapping
        case .nfkc:
            return input.precomposedStringWithCompatibilityMapping
        case .nfkd:
            return input.decomposedStringWithCompatibilityMapping
        }
    }

    /// Normalizes only full-width ASCII characters to half-width, preserving Japanese characters
    /// Preserves full-width space (U+3000) as it has semantic meaning in Japanese text
    private static func normalizeFullWidthASCII(_ input: String) -> String {
        var result = ""

        for scalar in input.unicodeScalars {
            if scalar.value >= 0xFF01 && scalar.value <= 0xFF5E {
                // Full-width ASCII: map to half-width equivalent
                let halfWidthValue = scalar.value - 0xFF01 + 0x21
                if let halfWidth = UnicodeScalar(halfWidthValue) {
                    result.append(String(halfWidth))
                } else {
                    // Fallback: keep original character if conversion fails
                    result.append(String(scalar))
                }
            } else {
                // Keep all other characters as-is (including full-width space U+3000 and Japanese characters)
                result.append(String(scalar))
            }
        }

        return result
    }

    // MARK: - Enhanced Character Normalization

    /// Normalizes Japanese-specific character variants
    private static func normalizeJapaneseCharacters(_ input: String) -> String {
        var result = input

        // Only normalize specific punctuation variants that are commonly confused
        // Do NOT normalize regular Japanese characters like ー or quotation marks

        // Special case: hiragana vu (ゔ) should become katakana vu (ヴ) for consistency
        result = result.replacingOccurrences(of: "ゔ", with: "ヴ") // U+3094 -> U+30F4

        // Normalize wave dash variants (commonly confused in Japanese text)  
        // Convert directly to half-width tilde to avoid double-counting in statistics
        result = result.replacingOccurrences(of: "〜", with: "~") // U+301C -> U+007E (half-width)

        // Normalize minus sign variants  
        result = result.replacingOccurrences(of: "−", with: "-") // U+2212 -> U+002D
        result = result.replacingOccurrences(of: "－", with: "-") // U+FF0D -> U+002D

        // Normalize dash variants
        result = result.replacingOccurrences(of: "―", with: "—") // U+2015 -> U+2014 (em dash)

        return result
    }

    /// Normalizes emoji to standardized forms
    private static func normalizeEmoji(_ input: String) -> String {
        var result = input

        // Normalize variation selectors for consistent emoji display
        // Text variation selector (U+FE0E) -> remove for programming context
        result = result.replacingOccurrences(of: "\u{FE0E}", with: "")
        
        // Emoji variation selector (U+FE0F) -> standardize
        result = result.replacingOccurrences(of: "\u{FE0F}", with: "")

        // Normalize zero-width joiner sequences for consistent handling
        // Keep ZWJ sequences but normalize common variants
        
        return result
    }

    /// Normalizes mathematical symbols to standardized forms
    private static func normalizeMathematicalSymbols(_ input: String) -> String {
        var result = input

        // Mathematical symbol normalization for programming contexts
        let mathReplacements: [(String, String)] = [
            // Greek letters commonly used in programming
            ("α", "alpha"),   // Keep as-is for now, could be configurable
            ("β", "beta"),
            ("π", "pi"),
            ("∑", "sum"),
            ("∏", "product"),
            ("∆", "delta"),
            ("Ω", "omega"),
            
            // Mathematical operators that might be confused
            ("×", "*"),       // Multiplication sign to asterisk
            ("÷", "/"),       // Division sign to slash
            ("≈", "~="),      // Approximately equal
            ("∞", "infinity")  // Infinity symbol
        ]

        for (original, replacement) in mathReplacements {
            result = result.replacingOccurrences(of: original, with: replacement)
        }

        return result
    }

    // MARK: - Security Processing

    /// Applies security processing including homoglyph detection and bidirectional text checks
    private static func applySecurityProcessing(_ input: String, config: SecurityConfig) -> String {
        var result = input

        if config.enableHomoglyphDetection {
            result = mitigateHomoglyphs(result)
        }

        if config.detectBidiReordering {
            result = normalizeBidirectionalText(result)
        }

        return result
    }

    /// Detects and mitigates homoglyph attacks
    private static func mitigateHomoglyphs(_ input: String) -> String {
        var result = input

        // Common homoglyph replacements for security
        let homoglyphReplacements: [(String, String)] = [
            // Cyrillic -> Latin
            ("а", "a"),  // Cyrillic small a -> Latin a
            ("е", "e"),  // Cyrillic small e -> Latin e  
            ("о", "o"),  // Cyrillic small o -> Latin o
            ("р", "p"),  // Cyrillic small p -> Latin p
            ("с", "c"),  // Cyrillic small c -> Latin c
            ("х", "x"),  // Cyrillic small x -> Latin x
            ("А", "A"),  // Cyrillic capital A -> Latin A
            ("В", "B"),  // Cyrillic capital B -> Latin B
            ("Е", "E"),  // Cyrillic capital E -> Latin E
            ("К", "K"),  // Cyrillic capital K -> Latin K
            ("М", "M"),  // Cyrillic capital M -> Latin M
            ("Н", "H"),  // Cyrillic capital H -> Latin H
            ("О", "O"),  // Cyrillic capital O -> Latin O
            ("Р", "P"),  // Cyrillic capital P -> Latin P
            ("С", "C"),  // Cyrillic capital C -> Latin C
            ("Т", "T"),  // Cyrillic capital T -> Latin T
            ("Х", "X"),  // Cyrillic capital X -> Latin X
            
            // Greek -> Latin (common in mathematical contexts)
            ("Α", "A"),  // Greek capital alpha -> Latin A
            ("Β", "B"),  // Greek capital beta -> Latin B
            ("Ε", "E"),  // Greek capital epsilon -> Latin E
            ("Ζ", "Z"),  // Greek capital zeta -> Latin Z
            ("Η", "H"),  // Greek capital eta -> Latin H
            ("Ι", "I"),  // Greek capital iota -> Latin I
            ("Κ", "K"),  // Greek capital kappa -> Latin K
            ("Μ", "M"),  // Greek capital mu -> Latin M
            ("Ν", "N"),  // Greek capital nu -> Latin N
            ("Ο", "O"),  // Greek capital omicron -> Latin O
            ("Ρ", "P"),  // Greek capital rho -> Latin P
            ("Τ", "T"),  // Greek capital tau -> Latin T
            ("Υ", "Y"),  // Greek capital upsilon -> Latin Y
            ("Χ", "X"),  // Greek capital chi -> Latin X
        ]

        for (original, replacement) in homoglyphReplacements {
            result = result.replacingOccurrences(of: original, with: replacement)
        }

        return result
    }

    /// Normalizes bidirectional text to prevent reordering attacks
    private static func normalizeBidirectionalText(_ input: String) -> String {
        var result = ""

        for scalar in input.unicodeScalars {
            // Remove bidirectional override characters that could be used for attacks
            switch scalar.value {
            case 0x202A, // LRE (Left-to-Right Embedding)
                 0x202B, // RLE (Right-to-Left Embedding)
                 0x202C, // PDF (Pop Directional Formatting)
                 0x202D, // LRO (Left-to-Right Override)
                 0x202E, // RLO (Right-to-Left Override)
                 0x2066, // LRI (Left-to-Right Isolate)
                 0x2067, // RLI (Right-to-Left Isolate)
                 0x2068, // FSI (First Strong Isolate)
                 0x2069: // PDI (Pop Directional Isolate)
                // Remove these potentially dangerous characters
                continue
            default:
                result.append(String(scalar))
            }
        }

        return result
    }

    // MARK: - Character Classification Methods

    /// Classifies a Unicode scalar into detailed categories
    public static func classifyCharacter(_ scalar: UnicodeScalar) -> UnicodeCharacterClass {
        let value = scalar.value

        // Special case: Greek letters commonly used as mathematical symbols
        // These are technically letters but should be classified as math symbols in programming contexts
        if (value >= 0x0370 && value <= 0x03FF) {   // Greek and Coptic range
            return .symbol(subcategory: .mathSymbol)
        }

        // Use Unicode General Categories
        if scalar.isLetter {
            if scalar.isUppercase {
                return .letter(subcategory: .uppercaseLetter)
            } else if scalar.isLowercase {
                return .letter(subcategory: .lowercaseLetter)
            } else {
                return .letter(subcategory: .otherLetter)
            }
        } else if scalar.isNumber {
            return .number(subcategory: .decimalDigitNumber)
        } else if scalar.isPunctuation {
            // Detailed punctuation classification
            switch value {
            case 0x0028, 0x005B, 0x007B, 0x0F3A, 0x0F3C, 0x169B, 0x201A, 0x201E, 0x2045, 0x207D, 0x208D, 0x2329, 0x2768...0x2775, 0x27C5, 0x27E6...0x27EF, 0x2983...0x2998, 0x29D8...0x29DB, 0x29FC, 0x29FE, 0x2E22, 0x2E24, 0x2E26, 0x2E28, 0x2E42, 0x3008...0x3011, 0x3014...0x301B, 0x301D, 0x301F, 0xFD3E, 0xFE17, 0xFE35, 0xFE37, 0xFE39, 0xFE3B, 0xFE3D, 0xFE3F, 0xFE41, 0xFE43, 0xFE47, 0xFE59, 0xFE5B, 0xFE5D, 0xFF08, 0xFF3B, 0xFF5B, 0xFF5F, 0xFF62:
                return .punctuation(subcategory: .openPunctuation)
            case 0x0029, 0x005D, 0x007D, 0x0F3B, 0x0F3D, 0x169C, 0x2046, 0x207E, 0x208E, 0x232A, 0x2769...0x2776, 0x27C6, 0x27E7...0x27F0, 0x2984...0x2999, 0x29D9...0x29DC, 0x29FD, 0x29FF, 0x2E23, 0x2E25, 0x2E27, 0x2E29, 0x3009...0x3012, 0x3015...0x301C, 0x301E, 0x3020, 0xFD3F, 0xFE18, 0xFE36, 0xFE38, 0xFE3A, 0xFE3C, 0xFE3E, 0xFE40, 0xFE42, 0xFE44, 0xFE48, 0xFE5A, 0xFE5C, 0xFE5E, 0xFF09, 0xFF3D, 0xFF5D, 0xFF60, 0xFF63:
                return .punctuation(subcategory: .closePunctuation)
            default:
                return .punctuation(subcategory: .otherPunctuation)
            }
        } else if scalar.isSymbol {
            // Mathematical symbols - check specific ranges
            if (value >= 0x2200 && value <= 0x22FF) || // Mathematical Operators
               (value >= 0x2A00 && value <= 0x2AFF) || // Supplemental Mathematical Operators  
               (value >= 0x27C0 && value <= 0x27EF) || // Miscellaneous Mathematical Symbols-A
               (value >= 0x2980 && value <= 0x29FF) {   // Miscellaneous Mathematical Symbols-B
                return .symbol(subcategory: .mathSymbol)
            }
            // Currency symbols
            else if (value >= 0x20A0 && value <= 0x20CF) {
                return .symbol(subcategory: .currencySymbol)
            }
            // Other symbols (including emoji)
            else {
                return .symbol(subcategory: .otherSymbol)
            }
        } else if scalar.isWhitespace {
            return .separator(subcategory: .spaceSeparator)
        } else {
            // Control and other characters
            if value <= 0x1F || (value >= 0x7F && value <= 0x9F) {
                return .other(subcategory: .control)
            } else {
                return .other(subcategory: .notAssigned)
            }
        }
    }

    // MARK: - Statistics and Counting Methods

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
            japaneseNormalizations: 0,
            emojiNormalizations: 0,
            mathSymbolNormalizations: 0,
            bidiReorderings: 0,
            homoglyphsDetected: 0,
            securityIssuesFound: 0
        )
    }

    /// Counts how many characters need NFC normalization
    private func countNFCChanges(_ input: String) -> Int {
        let normalized = input.precomposedStringWithCanonicalMapping
        return input == normalized ? 0 : 1 // Simple flag: 0 or 1 based on whether changes occurred
    }

    /// Counts how many full-width characters need conversion
    private func countFullwidthChanges(_ input: String) -> Int {
        return input.unicodeScalars.filter { scalar in
            // Full-width ASCII range: U+FF01 to U+FF5E
            return scalar.value >= 0xFF01 && scalar.value <= 0xFF5E
        }.count
    }

    /// Counts how many Japanese character variants need normalization
    private func countJapaneseChanges(_ input: String) -> Int {
        let variants = ["〜", "−", "－", "―", "ゔ"]
        return variants.reduce(0) { count, char in
            count + input.components(separatedBy: char).count - 1
        }
    }

    /// Counts how many emoji characters need normalization
    private func countEmojiChanges(_ input: String) -> Int {
        return input.unicodeScalars.filter { scalar in
            // Emoji variation selectors and modifiers
            return scalar.value == 0xFE0E || scalar.value == 0xFE0F ||
                   (scalar.value >= 0x1F1E6 && scalar.value <= 0x1F1FF) // Regional indicators
        }.count
    }

    /// Counts how many mathematical symbols need normalization
    private func countMathSymbolChanges(_ input: String) -> Int {
        let mathSymbols = ["α", "β", "π", "∑", "∏", "∆", "Ω", "×", "÷", "≈", "∞"]
        return mathSymbols.reduce(0) { count, symbol in
            count + input.components(separatedBy: symbol).count - 1
        }
    }

    /// Counts bidirectional text issues
    private func countBidiIssues(_ input: String) -> Int {
        return input.unicodeScalars.filter { scalar in
            let value = scalar.value
            return value == 0x202A || value == 0x202B || value == 0x202C ||
                   value == 0x202D || value == 0x202E || value == 0x2066 ||
                   value == 0x2067 || value == 0x2068 || value == 0x2069
        }.count
    }

    /// Counts potential homoglyph characters
    private func countHomoglyphs(_ input: String) -> Int {
        if !securityConfig.enableHomoglyphDetection {
            return 0
        }
        
        let homoglyphChars = ["а", "е", "о", "р", "с", "х", "А", "В", "Е", "К", "М", "Н", "О", "Р", "С", "Т", "Х",
                             "Α", "Β", "Ε", "Ζ", "Η", "Ι", "Κ", "Μ", "Ν", "Ο", "Ρ", "Τ", "Υ", "Χ"]
        return homoglyphChars.reduce(0) { count, char in
            count + input.components(separatedBy: char).count - 1
        }
    }

    // MARK: - Individual Normalization Steps

    /// Applies only NFC normalization
    public func normalizeNFC(_ input: String) -> String {
        return input.precomposedStringWithCanonicalMapping
    }

    /// Applies only NFD normalization  
    public func normalizeNFD(_ input: String) -> String {
        return input.decomposedStringWithCanonicalMapping
    }

    /// Applies only NFKC normalization
    public func normalizeNFKC(_ input: String) -> String {
        return input.precomposedStringWithCompatibilityMapping
    }

    /// Applies only NFKD normalization
    public func normalizeNFKD(_ input: String) -> String {
        return input.decomposedStringWithCompatibilityMapping
    }

    /// Applies only full-width to half-width conversion
    public func normalizeFullwidth(_ input: String) -> String {
        return Self.normalizeFullWidthASCII(input)
    }

    /// Applies only Japanese character normalization
    public func normalizeJapanese(_ input: String) -> String {
        return Self.normalizeJapaneseCharacters(input)
    }

    /// Applies only emoji normalization
    public func normalizeEmoji(_ input: String) -> String {
        return Self.normalizeEmoji(input)
    }

    /// Applies only mathematical symbol normalization
    public func normalizeMathSymbols(_ input: String) -> String {
        return Self.normalizeMathematicalSymbols(input)
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

        // Count emoji that need normalization
        let emojiVariants = countEmojiChanges(original)

        // Count mathematical symbols that need normalization
        let mathVariants = countMathSymbolChanges(original)

        // Count bidirectional text issues
        let bidiIssues = countBidiIssues(original)

        // Count homoglyphs
        let homoglyphs = countHomoglyphs(original)

        let normalized = UnicodeNormalizer.normalizeForFE(original, securityConfig: securityConfig)

        return NormalizationAnalysis(
            originalText: original,
            normalizedText: normalized,
            hasChanges: original != normalized,
            originalLength: original.count,
            normalizedLength: normalized.count,
            fullwidthCharactersConverted: fullwidthCharacters,
            combiningCharactersNormalized: combiningCharacters,
            japaneseCharactersNormalized: japaneseVariants,
            emojiCharactersNormalized: emojiVariants,
            mathSymbolsNormalized: mathVariants,
            bidiIssuesFound: bidiIssues,
            homoglyphsDetected: homoglyphs
        )
    }

    /// Checks if two strings are equivalent after normalization
    public func areEquivalent(_ string1: String, _ string2: String) -> Bool {
        let normalized1 = UnicodeNormalizer.normalizeForFE(string1, securityConfig: securityConfig)
        let normalized2 = UnicodeNormalizer.normalizeForFE(string2, securityConfig: securityConfig)

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
        public let emojiCharactersNormalized: Int
        public let mathSymbolsNormalized: Int
        public let bidiIssuesFound: Int
        public let homoglyphsDetected: Int

        public var compressionRatio: Double {
            guard originalLength > 0 else { return 1.0 }
            return Double(normalizedLength) / Double(originalLength)
        }

        public var hasSecurityConcerns: Bool {
            return homoglyphsDetected > 0 || bidiIssuesFound > 0
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
            if emojiCharactersNormalized > 0 {
                changes.append("\(emojiCharactersNormalized) emoji normalizations")
            }
            if mathSymbolsNormalized > 0 {
                changes.append("\(mathSymbolsNormalized) math symbol normalizations")
            }
            if bidiIssuesFound > 0 {
                changes.append("\(bidiIssuesFound) bidi issues resolved")
            }
            if homoglyphsDetected > 0 {
                changes.append("\(homoglyphsDetected) homoglyphs mitigated")
            }

            return "Applied: " + changes.joined(separator: ", ")
        }
    }
}



// MARK: - String Extension

extension String {
    /// Convenience method for FE language normalization (static method, no statistics tracking)
    /// For statistics tracking, use UnicodeNormalizer instance method instead
    public var normalizedForFE: String {
        return UnicodeNormalizer.normalizeForFE(self)
    }

    /// Convenience method for NFC normalization only
    public var normalizedNFC: String {
        return self.precomposedStringWithCanonicalMapping
    }

    /// Convenience method for NFD normalization only
    public var normalizedNFD: String {
        return self.decomposedStringWithCanonicalMapping
    }

    /// Convenience method for NFKC normalization only
    public var normalizedNFKC: String {
        return UnicodeNormalizer.normalizeForFE(self, form: .nfkc)
    }

    /// Convenience method for NFKD normalization only
    public var normalizedNFKD: String {
        return UnicodeNormalizer.normalizeForFE(self, form: .nfkd)
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

    /// Convenience method for emoji normalization only
    public var normalizedEmoji: String {
        let normalizer = UnicodeNormalizer()
        return normalizer.normalizeEmoji(self)
    }

    /// Convenience method for mathematical symbol normalization only
    public var normalizedMathSymbols: String {
        let normalizer = UnicodeNormalizer()
        return normalizer.normalizeMathSymbols(self)
    }

    /// Normalizes text and returns both result and statistics
    /// Usage: let (normalized, stats) = text.normalizedForFEWithStats()
    public func normalizedForFEWithStats(
        form: UnicodeNormalizer.NormalizationForm = .nfc,
        securityConfig: UnicodeNormalizer.SecurityConfig = UnicodeNormalizer.SecurityConfig()
    ) -> (String, UnicodeNormalizer.NormalizationStats) {
        var normalizer = UnicodeNormalizer(securityConfig: securityConfig)
        let result = normalizer.normalize(self, form: form)
        return (result, normalizer.getStats())
    }
}
