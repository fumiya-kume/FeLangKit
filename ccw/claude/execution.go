package claude

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
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

	// Prepare Claude Code command
	var args []string
	if ctx.IsRetry {
		args = []string{"--print"}
	} else {
		args = []string{}
	}

	// Create command with timeout
	cmdCtx, cancel := context.WithTimeout(context.Background(), ci.Timeout)
	defer cancel()

	cmd := exec.CommandContext(cmdCtx, "claude", args...)
	cmd.Dir = ctx.ProjectPath

	// Prepare input for Claude with issue context
	claudeInput := ci.buildClaudeInput(ctx)

	if !ctx.IsRetry {
		// Interactive mode for initial run
		// Write the context to a temporary file that Claude Code can read
		contextFile := filepath.Join(ctx.ProjectPath, ".claude-initial-prompt.md")
		if err := os.WriteFile(contextFile, []byte(claudeInput), 0644); err != nil {
			return fmt.Errorf("failed to write initial prompt: %w", err)
		}
		defer os.Remove(contextFile)

		// Capture stderr for error reporting while preserving interactive mode
		var stderrBuf strings.Builder
		cmd.Stdin = os.Stdin
		cmd.Stdout = os.Stdout
		cmd.Stderr = io.MultiWriter(os.Stderr, &stderrBuf)

		fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		fmt.Println("🤖 Starting Claude Code in interactive mode...")
		fmt.Println("📋 Issue context has been saved to: .claude-initial-prompt.md")
		fmt.Println("💡 Please read the file and implement the requested changes.")
		fmt.Println("✅ When done, exit Claude Code to continue with validation.")
		fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		fmt.Println()

		// Execute and wait for Claude Code to complete
		if err := cmd.Run(); err != nil {
			// Check if it was a timeout
			if cmdCtx.Err() == context.DeadlineExceeded {
				fmt.Printf("\n❌ Claude Code execution timed out after %v\n", ci.Timeout)
				if stderrOutput := strings.TrimSpace(stderrBuf.String()); stderrOutput != "" {
					fmt.Printf("Error output:\n%s\n", stderrOutput)
				}
				return fmt.Errorf("Claude Code execution timed out after %v", ci.Timeout)
			}
			
			// Print detailed error information
			fmt.Printf("\n❌ Claude Code execution failed with error: %v\n", err)
			if stderrOutput := strings.TrimSpace(stderrBuf.String()); stderrOutput != "" {
				fmt.Printf("Error output:\n%s\n", stderrOutput)
			}
			
			// Get exit code if available
			if exitError, ok := err.(*exec.ExitError); ok {
				fmt.Printf("Exit code: %d\n", exitError.ExitCode())
			}
			
			// Check common failure scenarios and provide helpful suggestions
			fmt.Println("\n🔍 Troubleshooting suggestions:")
			if strings.Contains(err.Error(), "executable file not found") {
				fmt.Println("- Claude Code CLI is not installed or not in PATH")
				fmt.Println("- Install from: https://claude.ai/code")
			} else if strings.Contains(err.Error(), "permission denied") {
				fmt.Println("- Check file permissions for Claude Code executable")
				fmt.Println("- Try: chmod +x $(which claude)")
			} else if strings.Contains(stderrBuf.String(), "authentication") {
				fmt.Println("- Claude Code authentication may have expired")
				fmt.Println("- Try: claude auth login")
			} else if strings.Contains(stderrBuf.String(), "network") {
				fmt.Println("- Network connectivity issues")
				fmt.Println("- Check internet connection and proxy settings")
			} else {
				fmt.Println("- Try running 'claude --help' to verify Claude Code installation")
				fmt.Println("- Check CCW logs for more details")
			}
			
			return fmt.Errorf("Claude Code execution failed: %w", err)
		}
		
		fmt.Println()
		fmt.Println("✅ Claude Code session completed. Proceeding with validation...")
		return nil
	} else {
		// Non-interactive mode for retries
		cmd.Stdin = strings.NewReader(claudeInput)
		output, err := cmd.CombinedOutput()
		if err != nil {
			return fmt.Errorf("Claude Code execution failed: %w\nOutput: %s", err, string(output))
		}

		fmt.Printf("Claude Code output:\n%s\n", string(output))
		return nil
	}
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
