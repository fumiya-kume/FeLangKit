package git

import (
	"fmt"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"time"

	"ccw/types"
)

// QualityValidator type is defined in types.go

// Validate implementation
func (qv *QualityValidator) ValidateImplementation(projectPath string) (*ValidationResult, error) {
	result := &ValidationResult{
		Success:   true,
		Timestamp: time.Now(),
	}
	start := time.Now()

	// Run SwiftLint
	if qv.swiftlintEnabled {
		lintResult, err := qv.runSwiftLint(projectPath)
		if err != nil {
			result.Success = false
			validationErr := types.NewCommandValidationError(
				"lint",
				"SwiftLint validation failed",
				"swiftlint lint",
				err,
				"",
				"",
				true,
			)
			validationErr.AddContext("project_path", projectPath)
			validationErr.AddContext("auto_fix_attempted", "true")
			result.Errors = append(result.Errors, validationErr)
		}
		result.LintResult = lintResult
		if lintResult != nil && !lintResult.Success {
			result.Success = false
		}
	}

	// Run build
	if qv.buildEnabled {
		buildResult, err := qv.runBuild(projectPath)
		if err != nil {
			result.Success = false
			validationErr := types.NewCommandValidationError(
				"build",
				"Swift build failed",
				"swift build",
				err,
				buildResult.Output,
				buildResult.Error,
				false,
			)
			validationErr.AddContext("project_path", projectPath)
			validationErr.AddContext("build_configuration", "debug")
			result.Errors = append(result.Errors, validationErr)
		}
		result.BuildResult = buildResult
		if buildResult != nil && !buildResult.Success {
			result.Success = false
		}
	}

	// Run tests
	if qv.testsEnabled {
		testResult, err := qv.runTests(projectPath)
		if err != nil {
			result.Success = false
			validationErr := types.NewCommandValidationError(
				"test",
				"Swift tests failed",
				"swift test",
				err,
				testResult.Output,
				"",
				false,
			)
			validationErr.AddContext("project_path", projectPath)
			validationErr.AddContext("test_count", fmt.Sprintf("%d", testResult.TestCount))
			validationErr.AddContext("failed_count", fmt.Sprintf("%d", testResult.Failed))
			result.Errors = append(result.Errors, validationErr)
		}
		result.TestResult = testResult
		if testResult != nil && !testResult.Success {
			result.Success = false
		}
	}

	result.Duration = time.Since(start)
	return result, nil
}

// Run SwiftLint
func (qv *QualityValidator) runSwiftLint(projectPath string) (*LintResult, error) {
	result := &LintResult{}

	// First, try to auto-fix
	fixCmd := exec.Command("swiftlint", "lint", "--fix")
	fixCmd.Dir = projectPath
	fixOutput, fixErr := fixCmd.CombinedOutput()
	if fixErr == nil {
		result.AutoFixed = true
	}

	// Then run lint check
	cmd := exec.Command("swiftlint", "lint")
	cmd.Dir = projectPath
	output, err := cmd.CombinedOutput()

	result.Output = string(output)
	result.Success = err == nil

	if err != nil {
		result.Errors = []string{err.Error()}
		// Try to extract specific errors from output
		lines := strings.Split(string(output), "\n")
		for _, line := range lines {
			if strings.Contains(line, "error:") || strings.Contains(line, "warning:") {
				if strings.Contains(line, "error:") {
					result.Errors = append(result.Errors, line)
				} else {
					result.Warnings = append(result.Warnings, line)
				}
			}
		}

		// Return detailed error with command context
		return result, fmt.Errorf("swiftlint validation failed: %w\nOutput: %s\nFix attempt output: %s",
			err, string(output), string(fixOutput))
	}

	return result, nil
}

// Run Swift build
func (qv *QualityValidator) runBuild(projectPath string) (*BuildResult, error) {
	cmd := exec.Command("swift", "build")
	cmd.Dir = projectPath
	output, err := cmd.CombinedOutput()

	result := &BuildResult{
		Success: err == nil,
		Output:  string(output),
	}

	if err != nil {
		result.Error = err.Error()
		return result, fmt.Errorf("swift build failed: %w\nOutput: %s", err, string(output))
	}

	return result, nil
}

// Run Swift tests
func (qv *QualityValidator) runTests(projectPath string) (*TestResult, error) {
	cmd := exec.Command("swift", "test")
	cmd.Dir = projectPath
	output, err := cmd.CombinedOutput()

	result := &TestResult{
		Success: err == nil,
		Output:  string(output),
	}

	// Try to parse test results
	outputStr := string(output)
	if strings.Contains(outputStr, "Test Suite") {
		// Parse test counts if available
		lines := strings.Split(outputStr, "\n")
		for _, line := range lines {
			if strings.Contains(line, "tests passed") {
				// Extract test numbers
				if matches := regexp.MustCompile(`(\d+) tests passed`).FindStringSubmatch(line); len(matches) > 1 {
					if count, err := strconv.Atoi(matches[1]); err == nil {
						result.Passed = count
					}
				}
			}
			if strings.Contains(line, "tests failed") {
				if matches := regexp.MustCompile(`(\d+) tests failed`).FindStringSubmatch(line); len(matches) > 1 {
					if count, err := strconv.Atoi(matches[1]); err == nil {
						result.Failed = count
					}
				}
			}
		}
		result.TestCount = result.Passed + result.Failed
	}

	if err != nil {
		return result, fmt.Errorf("swift test failed: %w\nOutput: %s\nTest results: %d passed, %d failed",
			err, string(output), result.Passed, result.Failed)
	}

	return result, nil
}

// Check if validation is needed (i.e., there are changes)
func (qv *QualityValidator) ShouldValidate(gitOps *GitOperations, worktreePath string) (bool, error) {
	hasChanges, err := gitOps.HasUncommittedChanges(worktreePath)
	if err != nil {
		return true, err // Default to validating if we can't check
	}

	if !hasChanges {
		// Check if there are any staged changes
		cmd := exec.Command("git", "diff", "--cached", "--name-only")
		cmd.Dir = worktreePath
		output, err := cmd.Output()
		if err != nil {
			return true, err
		}

		stagedFiles := strings.TrimSpace(string(output))
		return stagedFiles != "", nil
	}

	return hasChanges, nil
}

// Get validation summary for display
func (qv *QualityValidator) GetValidationSummary(result *ValidationResult) string {
	if result == nil {
		return "No validation performed"
	}

	var summary strings.Builder
	summary.WriteString(fmt.Sprintf("Validation completed in %v\n", result.Duration.Round(time.Millisecond)))

	if result.LintResult != nil {
		status := "✅ PASSED"
		if !result.LintResult.Success {
			status = "❌ FAILED"
		}
		summary.WriteString(fmt.Sprintf("- SwiftLint: %s", status))
		if result.LintResult.AutoFixed {
			summary.WriteString(" (auto-fixed)")
		}
		summary.WriteString("\n")
	}

	if result.BuildResult != nil {
		status := "✅ PASSED"
		if !result.BuildResult.Success {
			status = "❌ FAILED"
		}
		summary.WriteString(fmt.Sprintf("- Build: %s\n", status))
	}

	if result.TestResult != nil {
		status := "✅ PASSED"
		if !result.TestResult.Success {
			status = "❌ FAILED"
		}
		summary.WriteString(fmt.Sprintf("- Tests: %s", status))
		if result.TestResult.TestCount > 0 {
			summary.WriteString(fmt.Sprintf(" (%d passed, %d failed)", result.TestResult.Passed, result.TestResult.Failed))
		}
		summary.WriteString("\n")
	}

	if len(result.Errors) > 0 {
		summary.WriteString(fmt.Sprintf("\nErrors (%d):\n", len(result.Errors)))
		for _, err := range result.Errors {
			summary.WriteString(fmt.Sprintf("- [%s] %s\n", err.Type, err.Message))
			if err.Cause != nil {
				if err.Cause.Command != "" {
					summary.WriteString(fmt.Sprintf("  Command: %s\n", err.Cause.Command))
				}
				if err.Cause.ExitCode != 0 {
					summary.WriteString(fmt.Sprintf("  Exit Code: %d\n", err.Cause.ExitCode))
				}
				if err.Cause.RootError != "" {
					summary.WriteString(fmt.Sprintf("  Root Cause: %s\n", err.Cause.RootError))
				}
				if len(err.Cause.Context) > 0 {
					summary.WriteString("  Context:\n")
					for key, value := range err.Cause.Context {
						summary.WriteString(fmt.Sprintf("    %s: %s\n", key, value))
					}
				}
			}
		}
	}

	return summary.String()
}
