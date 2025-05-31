package claude

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"ccw/types"
)

// RunWithContext executes Claude Code with provided context
func (ci *ClaudeIntegration) RunWithContext(ctx *types.ClaudeContext) error {
	// Create JSON context file
	contextFile := filepath.Join(ctx.ProjectPath, ".claude-context.json")
	contextData, err := json.MarshalIndent(ctx, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal Claude context: %w", err)
	}

	if err := os.WriteFile(contextFile, contextData, 0644); err != nil {
		return fmt.Errorf("failed to write Claude context file: %w", err)
	}
	defer os.Remove(contextFile)

	// Create enhanced markdown context file (.claude-context.md)
	mdContextFile := filepath.Join(ctx.ProjectPath, ".claude-context.md")
	mdContent, err := ci.generateMarkdownContext(ctx)
	if err != nil {
		return fmt.Errorf("failed to generate markdown context: %w", err)
	}

	if err := os.WriteFile(mdContextFile, []byte(mdContent), 0644); err != nil {
		return fmt.Errorf("failed to write markdown context file: %w", err)
	}
	defer os.Remove(mdContextFile)

	// Use the correct Claude Code path
	claudePath := "/Users/kuu/.claude/local/claude"

	// Prepare input for Claude with issue context
	claudeInput := ci.buildClaudeInput(ctx)

	// Always use interactive mode with pre-filled prompt
	args := []string{claudeInput}

	// Create command - no timeout for interactive mode
	cmd := exec.Command(claudePath, args...)
	cmd.Dir = ctx.ProjectPath
	
	// Run Claude interactively with the prompt pre-loaded
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	
	if ctx.IsRetry {
		fmt.Printf("🔄 Starting Claude Code for recovery (Attempt %d/%d)...\n", ctx.RetryAttempt, ctx.MaxRetries)
		fmt.Printf("📝 Validation errors have been included in the context.\n")
	} else {
		fmt.Printf("🤖 Starting Claude Code in interactive mode with prepared context...\n")
	}
	fmt.Printf("🚀 Launching Claude Code...\n\n")

	// Run in interactive mode
	if err := cmd.Run(); err != nil {
		// Enhanced error reporting
		var errorDetails strings.Builder
		errorDetails.WriteString(fmt.Sprintf("Claude Code execution failed: %v\n", err))
		errorDetails.WriteString(fmt.Sprintf("Command: %s <prompt>\n", claudePath))
		errorDetails.WriteString(fmt.Sprintf("Working Directory: %s\n", ctx.ProjectPath))
		
		if exitError, ok := err.(*exec.ExitError); ok {
			errorDetails.WriteString(fmt.Sprintf("Exit Code: %d\n", exitError.ExitCode()))
		}
		
		// Check for common issues
		if strings.Contains(err.Error(), "executable file not found") {
			errorDetails.WriteString("\nPossible Solution: Ensure Claude Code is properly installed at /Users/kuu/.claude/local/claude\n")
		}
		
		return fmt.Errorf("%s", errorDetails.String())
	}
	
	return nil
}

// buildClaudeInput creates the input prompt for Claude Code
func (ci *ClaudeIntegration) buildClaudeInput(ctx *types.ClaudeContext) string {
	if ctx.IsRetry {
		return fmt.Sprintf(`
🔄 RECOVERY MODE - Validation Error Fixing (Attempt %d/%d)

The previous implementation failed validation. Please fix the following errors:

%s

GitHub Issue Context:
- Issue #%d: %s
- Project: %s
- Branch: %s

🎯 RECOVERY FOCUS:
Please analyze and fix the validation errors above. Common solutions:
- SwiftLint errors: Fix code formatting, naming conventions, remove unused imports
- Build errors: Fix compilation issues, missing imports, type mismatches
- Test failures: Fix test logic, update assertions, resolve test data issues

After making changes, run the validation sequence:
swiftlint lint --fix && swiftlint lint && swift build && swift test

Priority: Fix errors completely to pass validation on this attempt.
`,
			ctx.RetryAttempt,
			ctx.MaxRetries,
			formatValidationErrorsDetailed(ctx.ValidationErrors),
			ctx.IssueData.Number,
			ctx.IssueData.Title,
			ctx.ProjectPath,
			ctx.WorktreeConfig.BranchName,
		)
	} else {
		return fmt.Sprintf(`
Please work on GitHub issue #%d: %s

Issue Description:
%s

Project Path: %s
Worktree Branch: %s

Please implement the requested changes and run the complete validation sequence:
swiftlint lint --fix && swiftlint lint && swift build && swift test
`,
			ctx.IssueData.Number,
			ctx.IssueData.Title,
			ctx.IssueData.Body,
			ctx.ProjectPath,
			ctx.WorktreeConfig.BranchName,
		)
	}
}

// formatValidationErrors formats validation errors for display
func formatValidationErrors(errors []types.ValidationError) string {
	if len(errors) == 0 {
		return "None"
	}

	var errorStrings []string
	for _, err := range errors {
		errorStrings = append(errorStrings, fmt.Sprintf("- %s: %s", err.Type, err.Message))
	}
	return strings.Join(errorStrings, "\n")
}

// formatValidationErrorsDetailed formats validation errors with detailed information for recovery
func formatValidationErrorsDetailed(errors []types.ValidationError) string {
	if len(errors) == 0 {
		return "✅ No validation errors found."
	}

	// Group errors by type
	errorsByType := make(map[string][]types.ValidationError)
	for _, err := range errors {
		errorsByType[err.Type] = append(errorsByType[err.Type], err)
	}

	var output strings.Builder

	for errorType, errs := range errorsByType {
		output.WriteString(fmt.Sprintf("━━━ %s ERRORS (%d) ━━━\n", strings.ToUpper(errorType), len(errs)))

		for i, err := range errs {
			output.WriteString(fmt.Sprintf("%d. ", i+1))
			if err.File != "" && err.Line > 0 {
				output.WriteString(fmt.Sprintf("📁 %s:%d\n", err.File, err.Line))
			}
			output.WriteString(fmt.Sprintf("   💬 %s\n", err.Message))

			// Add detailed cause information if available
			if err.Cause != nil {
				if err.Cause.Command != "" {
					output.WriteString(fmt.Sprintf("   🔧 Command: %s\n", err.Cause.Command))
				}
				if err.Cause.ExitCode != 0 {
					output.WriteString(fmt.Sprintf("   💥 Exit Code: %d\n", err.Cause.ExitCode))
				}
				if err.Cause.RootError != "" {
					output.WriteString(fmt.Sprintf("   🔍 Root Cause: %s\n", err.Cause.RootError))
				}
				if err.Cause.Stderr != "" && err.Cause.Stderr != err.Cause.RootError {
					// Truncate stderr if too long for better readability
					stderr := err.Cause.Stderr
					if len(stderr) > 200 {
						stderr = stderr[:200] + "..."
					}
					output.WriteString(fmt.Sprintf("   📄 Error Output: %s\n", stderr))
				}
				if len(err.Cause.Context) > 0 {
					output.WriteString("   📋 Context:\n")
					for key, value := range err.Cause.Context {
						output.WriteString(fmt.Sprintf("      %s: %s\n", key, value))
					}
				}
			}

			if err.Recoverable {
				output.WriteString("   🔧 Recoverable: YES\n")
			} else {
				output.WriteString("   ⚠️  Recoverable: NO\n")
			}
			output.WriteString("\n")
		}
	}

	// Add helpful recovery suggestions
	output.WriteString("🔍 RECOVERY SUGGESTIONS:\n")

	if _, hasLint := errorsByType["lint"]; hasLint {
		output.WriteString("• SwiftLint: Run 'swiftlint lint --fix' first, then manually fix remaining issues\n")
	}

	if _, hasBuild := errorsByType["build"]; hasBuild {
		output.WriteString("• Build: Check imports, types, and syntax. Look for compilation errors in output\n")
	}

	if _, hasTest := errorsByType["test"]; hasTest {
		output.WriteString("• Tests: Check test logic, assertions, and test data. Run individual tests to isolate issues\n")
	}

	return output.String()
}
