# FeLangKit

Swift library for parsing and analyzing the FE pseudo-language.

## Requirements

- Swift 6.0+
- macOS 13.0+ / iOS 17.0+ / Linux

## Install (SPM)

Package.swift:

```swift
dependencies: [
    .package(url: "https://github.com/fumiya-kume/FeLangKit.git", from: "1.0.0")
]
```

Xcode:
1. File > Add Packages...
2. `https://github.com/fumiya-kume/FeLangKit.git`
3. Add the product you need: `FeLangCore`, `FeLangKit`, `FeLangRuntime`, or `FeLangServer`

## Quick Start

```swift
import FeLangCore

let tokenizer = Tokenizer(input: "x ← 1 + 2")
let tokens = try tokenizer.tokenize()

let expressionParser = ExpressionParser()
let expression = try expressionParser.parseExpression(from: tokens)

let statementParser = StatementParser()
let statements = try statementParser.parseStatements(from: tokens)
```

## iOS Usage

### Code Execution

```swift
import FeLangRuntime

let interpreter = Interpreter.withCustomIO(
    printHandler: { text in /* Display output in UI */ },
    inputHandler: { /* Get input from UI */ return nil }
)
try interpreter.execute("x: integer ← 42\nprint(x)")
```

### IDE Features (Completion, Diagnostics, Hover)

```swift
import FeLangServer

let (server, transport) = LanguageServer.createInMemory()
Task { await server.run() }

await transport.sendInitialize()
await transport.sendDidOpen(uri: "file:///main.fe", content: sourceCode)

for await message in transport.output {
    switch message {
    case .response(let response):
        // Handle response
    case .notification(let method, let params):
        // Handle diagnostics etc.
    }
}
```

## Modules

- `FeLangCore`: tokenizer, expression parser, statement parser, utilities
- `FeLangRuntime`: interpreter/runtime
- `FeLangKit`: convenience umbrella for core + runtime
- `FeLangServer`: diagnostics support (server-side usage)

## Docs

- Architecture: `docs/ARCHITECTURE.md`
- Testing: `docs/TESTING.md`
- Development: `docs/DEVELOPMENT.md`
- Migration: `docs/MIGRATION.md`
- Design docs: `docs/design/`
- Performance notes: `docs/performance-analysis-summary.md`

## License

MIT. See `LICENSE`.
