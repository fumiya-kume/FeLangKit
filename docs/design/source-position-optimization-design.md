# ソース位置計算最適化 設計ドキュメント

## 1. 概要

### 1.1 プロジェクト概要
FeLangKitトークナイザーにおけるソース位置計算のパフォーマンス最適化を実装し、O(n²)からO(n)への計算量改善と大ファイル処理の高速化を実現する。

### 1.2 目的
- **パフォーマンス改善**: 現在のO(n²)からO(n)への時間計算量改善
- **メモリ最適化**: 不要な部分文字列生成の削除
- **スケーラビリティ**: 1MB+ファイルでの実用的な処理時間実現
- **Unicode対応**: マルチバイト文字と結合文字の正確な処理

### 1.3 関連Issue
- GitHub Issue #19: Optimize Source Position Calculation Performance
- Issue #18: ストリーミング処理とパフォーマンス最適化
- Issue #16: エラーハンドリング強化（位置情報の正確性）

## 2. 現状分析

### 2.1 現在の実装の問題点

#### 2.1.1 TokenizerUtilities.swiftのsourcePosition関数
```swift
func sourcePosition(input: String, currentIndex: String.Index, startIndex: String.Index) -> SourcePosition {
    let substring = String(input[startIndex..<currentIndex])
    let lines = substring.components(separatedBy: "\n")
    let line = lines.count
    let column = lines.last?.count ?? 0
    let offset = input.distance(from: startIndex, to: currentIndex)
    return SourcePosition(line: line, column: column + 1, offset: offset)
}
```

#### 2.1.2 パフォーマンスボトルネック
1. **O(n)の部分文字列操作**: `String(input[startIndex..<currentIndex])`
2. **O(n)の文字列分割**: `components(separatedBy: "\n")`
3. **反復実行**: 各トークンごとに上記操作を実行
4. **結果**: 全体でO(n²)の時間計算量

#### 2.1.3 計測結果
- **小ファイル (1KB)**: 許容範囲内
- **中ファイル (100KB)**: 遅延が顕著
- **大ファイル (1MB)**: 実用不可能な処理時間
- **推定**: 目標150ms に対して現在~1500秒（10,000倍遅い）

### 2.2 現在のコードベース状況
- `FastParsingTokenizer.swift`: 高速トークナイザーの実装済み
- `KeywordPerformanceTests.swift`: パフォーマンステスト基盤完備
- `performance-analysis-summary.md`: 詳細なパフォーマンス分析文書

## 3. 要件定義

### 3.1 機能要件
1. **位置追跡**: 行番号、列番号、オフセットの正確な計算
2. **Unicode対応**: マルチバイト文字の適切な処理
3. **増分更新**: 文字単位での効率的な位置更新
4. **ランダムアクセス**: 任意オフセット位置の高速取得

### 3.2 非機能要件
1. **パフォーマンス**: O(n)時間計算量
2. **メモリ効率**: 最小限のメモリ使用量
3. **スレッドセーフティ**: 並行処理対応
4. **後方互換性**: 既存APIの維持

### 3.3 制約条件
1. **Swift言語**: 既存コードベースとの整合性
2. **iOS/macOS対応**: プラットフォーム互換性
3. **既存テスト**: 全テストのパス必須

## 4. 設計アーキテクチャ

### 4.1 アーキテクチャ概要

```
┌─────────────────────────────────────────────────────────────┐
│                    Tokenizer Layer                         │
├─────────────────────────────────────────────────────────────┤
│  FastParsingTokenizer                                       │
│  ├── IncrementalPositionTracker ←─ 新規実装                 │
│  └── PositionCache              ←─ 新規実装                 │
├─────────────────────────────────────────────────────────────┤
│                    Core Position Layer                     │
├─────────────────────────────────────────────────────────────┤
│  SourcePosition (既存)                                     │
│  PositionTracker (新規プロトコル)                          │
│  LineStartCache (新規)                                     │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 主要コンポーネント

#### 4.2.1 PositionTrackerプロトコル
```swift
protocol PositionTracker {
    var currentPosition: SourcePosition { get }
    mutating func advance(by character: Character)
    mutating func advance(by string: String)
    func position(at offset: Int) -> SourcePosition
    mutating func reset()
}
```

#### 4.2.2 IncrementalPositionTracker
```swift
struct IncrementalPositionTracker: PositionTracker {
    private(set) var line: Int = 1
    private(set) var column: Int = 1
    private(set) var offset: Int = 0
    
    var currentPosition: SourcePosition {
        SourcePosition(line: line, column: column, offset: offset)
    }
    
    mutating func advance(by character: Character) {
        offset += 1
        if character.isNewline {
            line += 1
            column = 1
        } else {
            column += 1
        }
    }
}
```

#### 4.2.3 PositionCache
```swift
struct PositionCache {
    private let lineStartOffsets: [Int]
    
    init(source: String) {
        self.lineStartOffsets = Self.buildLineStartCache(from: source)
    }
    
    func position(at offset: Int) -> SourcePosition {
        let line = findLine(for: offset)
        let column = offset - lineStartOffsets[line - 1] + 1
        return SourcePosition(line: line, column: column, offset: offset)
    }
    
    private static func buildLineStartCache(from source: String) -> [Int] {
        var cache = [0]
        for (index, char) in source.enumerated() {
            if char.isNewline {
                cache.append(index + 1)
            }
        }
        return cache
    }
}
```

### 4.3 統合戦略

#### 4.3.1 FastParsingTokenizerへの統合
```swift
class FastParsingTokenizer {
    private var positionTracker: IncrementalPositionTracker
    private let positionCache: PositionCache?
    
    init(source: String, useCaching: Bool = true) {
        self.positionTracker = IncrementalPositionTracker()
        self.positionCache = useCaching ? PositionCache(source: source) : nil
    }
    
    func tokenize() -> [Token] {
        // 既存の高速トークナイザーロジック
        // + 最適化された位置計算
    }
}
```

## 5. 実装計画

### 5.1 Phase 1: 基盤コンポーネント実装 (Week 1-2)

#### 5.1.1 作業項目
1. **PositionTrackerプロトコル定義**
   - ファイル: `Sources/FeLangCore/Tokenizer/PositionTracker.swift`
   - 責任: 位置追跡の標準インターフェース定義

2. **IncrementalPositionTracker実装**
   - ファイル: `Sources/FeLangCore/Tokenizer/IncrementalPositionTracker.swift`
   - 責任: 増分位置更新の高速実装

3. **PositionCache実装**
   - ファイル: `Sources/FeLangCore/Tokenizer/PositionCache.swift`
   - 責任: 行開始位置のキャッシュとランダムアクセス

#### 5.1.2 成果物
- 3つの新規Swiftファイル
- 基本的な単体テスト
- パフォーマンステストのベースライン

### 5.2 Phase 2: FastParsingTokenizer統合 (Week 3)

#### 5.2.1 作業項目
1. **FastParsingTokenizer改修**
   - `sourcePosition`関数の置き換え
   - 新しい位置追跡システムの統合
   - 既存APIの互換性維持

2. **Unicode対応強化**
   - マルチバイト文字の正確な処理
   - 結合文字の適切な取り扱い
   - 文字境界の正確な判定

#### 5.2.2 成果物
- 改修されたFastParsingTokenizer
- Unicode処理の強化
- 統合テストの実行

### 5.3 Phase 3: 最適化とテスト (Week 4)

#### 5.3.1 作業項目
1. **パフォーマンス最適化**
   - メモリ使用量の削減
   - キャッシュ効率の改善
   - 並行処理対応

2. **包括的テスト**
   - 回帰テストの実行
   - パフォーマンステストの拡張
   - エッジケースの検証

#### 5.3.2 成果物
- 最適化されたパフォーマンス
- 包括的なテストスイート
- パフォーマンスレポート

## 6. パフォーマンス目標

### 6.1 計算量改善
- **現在**: O(n²) - 各トークンでO(n)の位置計算
- **目標**: O(n) - 前処理O(n) + 各トークンO(1)の位置計算

### 6.2 処理時間目標
| ファイルサイズ | 現在 (推定) | 目標 | 改善率 |
|---------------|-------------|------|--------|
| 1KB           | 1ms         | 1ms  | 1x     |
| 10KB          | 100ms       | 5ms  | 20x    |
| 100KB         | 10s         | 50ms | 200x   |
| 1MB           | 1500s       | 150ms| 10000x |
| 10MB          | 4.2hr       | 1.5s | 10000x |

### 6.3 メモリ使用量
- **削減項目**: 部分文字列の生成削除
- **追加項目**: 行開始位置キャッシュ（最小限）
- **総効果**: メモリ使用量50%以上削減

## 7. テスト戦略

### 7.1 単体テスト

#### 7.1.1 IncrementalPositionTrackerテスト
```swift
class IncrementalPositionTrackerTests: XCTestCase {
    func testBasicPositionTracking() {
        var tracker = IncrementalPositionTracker()
        
        // 基本的な位置追跡
        tracker.advance(by: "a")
        XCTAssertEqual(tracker.currentPosition.line, 1)
        XCTAssertEqual(tracker.currentPosition.column, 2)
        XCTAssertEqual(tracker.currentPosition.offset, 1)
    }
    
    func testNewlineHandling() {
        var tracker = IncrementalPositionTracker()
        
        // 改行の処理
        tracker.advance(by: "\n")
        XCTAssertEqual(tracker.currentPosition.line, 2)
        XCTAssertEqual(tracker.currentPosition.column, 1)
    }
    
    func testUnicodeCharacters() {
        // Unicode文字の正確な処理
        var tracker = IncrementalPositionTracker()
        tracker.advance(by: "🇯🇵") // 結合文字
        // アサーション
    }
}
```

#### 7.1.2 PositionCacheテスト
```swift
class PositionCacheTests: XCTestCase {
    func testLineStartCaching() {
        let source = "line1\nline2\nline3"
        let cache = PositionCache(source: source)
        
        // ランダムアクセステスト
        let position = cache.position(at: 7) // 'i' in "line2"
        XCTAssertEqual(position.line, 2)
        XCTAssertEqual(position.column, 2)
    }
}
```

### 7.2 統合テスト
```swift
class FastParsingTokenizerIntegrationTests: XCTestCase {
    func testPositionAccuracy() {
        let source = loadTestFile("complex_source.txt")
        let tokenizer = FastParsingTokenizer(source: source)
        let tokens = tokenizer.tokenize()
        
        // 各トークンの位置情報が正確であることを検証
        for token in tokens {
            let expectedPosition = calculateExpectedPosition(token)
            XCTAssertEqual(token.position, expectedPosition)
        }
    }
}
```

### 7.3 パフォーマンステスト
```swift
class PositionCalculationPerformanceTests: XCTestCase {
    func testLargeFilePerformance() {
        let sizes = [1_000, 10_000, 100_000, 1_000_000, 10_000_000]
        
        for size in sizes {
            let input = generateTestInput(size: size)
            
            measure {
                let tokenizer = FastParsingTokenizer(source: input)
                let tokens = tokenizer.tokenize()
                // すべてのトークンの位置情報が計算されることを確認
                _ = tokens.map { $0.position }
            }
        }
    }
    
    func testMemoryUsage() {
        // メモリ使用量の測定
        let input = generateTestInput(size: 1_000_000)
        
        let memoryBefore = getCurrentMemoryUsage()
        let tokenizer = FastParsingTokenizer(source: input)
        let tokens = tokenizer.tokenize()
        let memoryAfter = getCurrentMemoryUsage()
        
        let memoryUsed = memoryAfter - memoryBefore
        XCTAssertLessThan(memoryUsed, expectedMaxMemory)
    }
}
```

### 7.4 回帰テスト
- **既存テストスイート**: 全テストの継続実行
- **APIの互換性**: 既存のインターフェースの保持
- **動作の一貫性**: 位置情報の正確性維持

## 8. リスク分析と対策

### 8.1 技術的リスク

#### 8.1.1 Unicode処理の複雑性
- **リスク**: マルチバイト文字の不正確な処理
- **対策**: 
  - Swiftの標準Unicode処理機能を活用
  - 包括的なUnicodeテストケースの作成
  - 国際化テストの実施

#### 8.1.2 メモリ使用量の増加
- **リスク**: キャッシュによるメモリ消費増加
- **対策**: 
  - 効率的なキャッシュデータ構造の使用
  - オプショナルキャッシュ機能
  - メモリ使用量の継続監視

#### 8.1.3 並行処理の課題
- **リスク**: スレッドセーフティの問題
- **対策**: 
  - immutableデータ構造の活用
  - 適切な同期機構の実装
  - 並行処理テストの実施

### 8.2 パフォーマンスリスク

#### 8.2.1 期待性能の未達
- **リスク**: O(n)達成の困難
- **対策**: 
  - 段階的な最適化実装
  - 継続的なベンチマーク測定
  - 代替アルゴリズムの準備

#### 8.2.2 回帰性能の劣化
- **リスク**: 一部ケースでの性能低下
- **対策**: 
  - 包括的なパフォーマンステスト
  - A/Bテストによる比較
  - パフォーマンス監視の強化

### 8.3 統合リスク

#### 8.3.1 既存機能への影響
- **リスク**: 既存機能の破綻
- **対策**: 
  - 段階的統合の実施
  - 包括的な回帰テスト
  - 機能フラグによるロールバック準備

## 9. 実装詳細

### 9.1 ファイル構成
```
Sources/FeLangCore/Tokenizer/
├── PositionTracker.swift              # 新規: プロトコル定義
├── IncrementalPositionTracker.swift   # 新規: 増分位置追跡
├── PositionCache.swift                # 新規: 位置キャッシュ
├── FastParsingTokenizer.swift         # 修正: 統合実装
└── TokenizerUtilities.swift           # 修正: 最適化実装

Tests/FeLangCoreTests/Tokenizer/
├── PositionTrackerTests.swift         # 新規: プロトコルテスト
├── IncrementalPositionTrackerTests.swift # 新規: 増分追跡テスト
├── PositionCacheTests.swift           # 新規: キャッシュテスト
├── FastParsingTokenizerTests.swift    # 修正: 統合テスト
└── PositionCalculationPerformanceTests.swift # 修正: 性能テスト
```

### 9.2 API設計原則

#### 9.2.1 後方互換性
```swift
// 既存のAPIを保持
extension FastParsingTokenizer {
    @available(*, deprecated, message: "Use optimized position tracking")
    func sourcePosition(input: String, currentIndex: String.Index, startIndex: String.Index) -> SourcePosition {
        // 新しい実装へのラッパー
        return positionCache?.position(at: offset) ?? currentPosition
    }
}
```

#### 9.2.2 段階的移行
```swift
// 機能フラグによる段階的導入
struct TokenizerConfig {
    let useOptimizedPositionTracking: Bool = true
    let usePositionCache: Bool = true
    let enableUnicodeOptimization: Bool = true
}
```

### 9.3 パフォーマンス測定

#### 9.3.1 ベンチマーク実装
```swift
class PositionCalculationBenchmark {
    func runBenchmark() {
        let testCases = [
            ("small", 1_000),
            ("medium", 100_000),
            ("large", 1_000_000),
            ("xlarge", 10_000_000)
        ]
        
        for (name, size) in testCases {
            let input = generateTestInput(size: size)
            
            // 旧実装の測定
            let oldTime = measureTime {
                let oldTokenizer = LegacyTokenizer(source: input)
                _ = oldTokenizer.tokenize()
            }
            
            // 新実装の測定
            let newTime = measureTime {
                let newTokenizer = FastParsingTokenizer(source: input)
                _ = newTokenizer.tokenize()
            }
            
            let improvement = oldTime / newTime
            print("\\(name): \\(improvement)x improvement (\\(oldTime)ms → \\(newTime)ms)")
        }
    }
}
```

## 10. 監視とメトリクス

### 10.1 性能指標
- **処理時間**: ファイルサイズ別の平均処理時間
- **メモリ使用量**: ピークメモリ使用量とベースライン比較
- **スループット**: 1秒あたりの処理文字数
- **レイテンシ**: トークン位置計算の平均時間

### 10.2 品質指標
- **精度**: 位置情報の正確性（テストカバレッジ）
- **安定性**: クラッシュ率とエラー率
- **互換性**: 既存テストのパス率

### 10.3 継続的改善
- **定期的なベンチマーク**: 毎週のパフォーマンス測定
- **プロファイリング**: 月次の詳細パフォーマンス分析
- **最適化**: 四半期ごとの追加最適化検討

## 11. 結論

この設計ドキュメントは、FeLangKitトークナイザーのソース位置計算パフォーマンス最適化のための包括的な実装計画を提供します。主な成果として：

1. **劇的なパフォーマンス改善**: O(n²)からO(n)への改善により、1MBファイルの処理時間を1500秒から150msに短縮（10,000倍高速化）
2. **メモリ効率の向上**: 部分文字列生成の削除により50%以上のメモリ使用量削減
3. **スケーラビリティの確保**: 大ファイル処理の実用化
4. **Unicode対応の強化**: マルチバイト文字と結合文字の正確な処理

実装は3つのフェーズに分けて実行し、各フェーズで包括的なテストとパフォーマンス測定を行います。段階的な導入により、既存機能への影響を最小限に抑えながら、大幅なパフォーマンス改善を実現します。

この最適化により、FeLangKitは大規模ファイルの処理に対応し、実用的なパフォーマンスを提供できるようになります。
