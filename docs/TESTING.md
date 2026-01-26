# Testing

This document describes the testing strategy, organization, and day-to-day commands for FeLangKit.

## Test Pyramid

Prefer a test pyramid:

- **Unit tests (fast)**: Parser/Tokenizer/Semantic analysis + runtime evaluator/executor + standard library.
- **E2E tests (slow)**: Minimal smoke tests verifying integrations (e.g. CLI flags, stdin/file handling, full interpreter pipeline).

E2E tests should avoid duplicating fine-grained behavior that is already covered by unit tests.

## Test Targets

- `Tests/FeLangCoreTests/`: Tokenizer, parser, semantic analysis, pretty-printer, utilities.
- `Tests/FeLangRuntimeTests/`: Runtime values, expression evaluator, statement executor, standard library.
- `Tests/FeLangServerTests/`: Language server / transport integration.
- `Tests/FeLangE2ETests/`: CLI integration and end-to-end smoke tests.

## E2E Helpers

`FeLangE2ETests` provides two helpers:

- `InProcessTestHelper`: Executes `Interpreter.execute` in-process.
  - Fast, but **all executions are serialized** with a global lock due to interpreter thread-safety issues.
  - Use for smoke tests that don't need CLI behavior.
- `CLITestHelper`: Spawns the `felang` executable.
  - Use for tests that need CLI behavior (stdin/file args, exit codes, stderr, help output).

## Running Tests

Run all tests:

```bash
swift test
```

Run a specific suite or test:

```bash
swift test --filter "ExpressionParser Tests"
swift test --filter "CLI Basic Tests"
swift test --filter testUnaryMinusWithParentheses
```

Coverage (SwiftPM):

```bash
swift test --enable-code-coverage
```

## Listing Unused Code

This repository includes a Periphery helper script:

```bash
scripts/unused-code.sh
```

Periphery is required:

```bash
brew install peripheryapp/periphery/periphery
```
3. **Use Conventions**: Follow naming and structure guidelines
4. **Document Complex Cases**: Add comments for non-obvious test scenarios
5. **Run Full Suite**: Ensure new tests don't break existing functionality

### **Test Review Guidelines**
- Tests should be clear and focused on a single concern
- Edge cases and error conditions should be covered
- Performance impact should be considered
- Integration with existing test suite should be verified

This comprehensive testing strategy ensures FeLangCore maintains high quality and reliability! 🎉 
