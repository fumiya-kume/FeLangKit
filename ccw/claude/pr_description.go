package claude

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"ccw/types"
)

// GeneratePRDescriptionAsync generates PR description asynchronously
func (ci *ClaudeIntegration) GeneratePRDescriptionAsync(req *types.PRDescriptionRequest) <-chan types.PRDescriptionResult {
	resultChan := make(chan types.PRDescriptionResult, 1)

	go func() {
		defer close(resultChan)

		description, err := ci.generatePRDescriptionSync(req)
		resultChan <- types.PRDescriptionResult{
			Description: description,
			Error:       err,
		}
	}()

	return resultChan
}

// GeneratePRDescription generates PR description synchronously (legacy method)
func (ci *ClaudeIntegration) GeneratePRDescription(req *types.PRDescriptionRequest) (string, error) {
	return ci.generatePRDescriptionSync(req)
}

// generatePRDescriptionSync generates PR description synchronously
func (ci *ClaudeIntegration) generatePRDescriptionSync(req *types.PRDescriptionRequest) (string, error) {
	// Create context file for PR description generation
	contextFile := filepath.Join(req.WorktreeConfig.WorktreePath, ".claude-pr-context.json")
	contextData, err := json.MarshalIndent(req, "", "  ")
	if err != nil {
		return "", fmt.Errorf("failed to marshal PR description context: %w", err)
	}

	if err := os.WriteFile(contextFile, contextData, 0644); err != nil {
		return "", fmt.Errorf("failed to write PR description context file: %w", err)
	}
	defer os.Remove(contextFile)

	// Create command with timeout
	cmdCtx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	cmd := exec.CommandContext(cmdCtx, "claude", "--print")
	cmd.Dir = req.WorktreeConfig.WorktreePath

	// Prepare Claude prompt for PR description generation
	claudeInput := ci.buildPRDescriptionPrompt(req)

	cmd.Stdin = strings.NewReader(claudeInput)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("Claude Code PR description generation failed: %w\nOutput: %s", err, string(output))
	}

	// Extract the description from Claude's output
	description := strings.TrimSpace(string(output))

	// Basic validation that we got markdown content
	if len(description) < 100 || !strings.Contains(description, "##") {
		return "", fmt.Errorf("Claude Code returned invalid or incomplete PR description")
	}

	return description, nil
}

// buildPRDescriptionPrompt creates the prompt for PR description generation
func (ci *ClaudeIntegration) buildPRDescriptionPrompt(req *types.PRDescriptionRequest) string {
	return fmt.Sprintf(`
Please generate a comprehensive pull request description for GitHub issue #%d: %s

Issue Description:
%s

Implementation Summary:
%s

Validation Results:
- SwiftLint: %s
- Build: %s
- Tests: %s

Please create a detailed PR description in Markdown format with the following sections:

## Summary
Concise overview of what this PR accomplishes and its main value

## Background & Context
Provide detailed background about the issue and context:
- **Original Issue:** Detailed explanation of the problem that was reported or identified
- **Root Cause:** What was causing the issue (if applicable)
- **User Impact:** How this issue affected users or the development process
- **Previous State:** Describe how things worked before this change
- **Requirements:** What specific requirements needed to be met

## Solution Approach
Explain the solution and reasoning in detail:
- **Core Solution:** Clear explanation of how this PR solves the identified problem
- **Technical Strategy:** The overall technical approach chosen
- **Logic & Reasoning:** Detailed explanation of the implementation logic and why this approach was selected
- **Alternative Approaches:** Briefly mention other approaches considered and why they were not chosen
- **Architecture Changes:** Any changes to the overall system architecture or design patterns

## Implementation Details
Technical implementation breakdown:
- **Key Components:** Main components or modules that were modified/added
- **Code Changes:** Detailed explanation of the major code changes made
- **Files Modified:** List of files changed with brief explanation of changes in each
- **New Functionality:** Any new features or capabilities added
- **Integration Points:** How this change integrates with existing code
- **Error Handling:** How errors and edge cases are handled

## Technical Logic
Explain the technical reasoning and logic:
- **Algorithm/Logic:** Step-by-step explanation of key algorithms or logic implemented
- **Data Flow:** How data flows through the new/modified components
- **Performance Considerations:** Any performance optimizations or trade-offs made
- **Security Considerations:** Security implications and measures taken
- **Backwards Compatibility:** How backwards compatibility is maintained (if applicable)

## Testing & Validation
Comprehensive testing approach:
- **Test Strategy:** Overall testing approach used
- **Test Coverage:** Specific tests added and what they validate
- **Manual Testing:** Manual testing performed and results
- **Edge Cases:** Edge cases tested and how they are handled
- **Quality Assurance:** SwiftLint, build, and test results

## Impact & Future Work
Analysis of impact and future implications:
- **Breaking Changes:** Any breaking changes with migration guidance
- **Performance Impact:** Measured or expected performance changes
- **Maintenance Impact:** How this affects ongoing maintenance
- **Future Enhancements:** How this change enables or supports future work
- **Technical Debt:** Any technical debt introduced or resolved

Please respond with ONLY the Markdown content for the PR description, no additional text or formatting.
`,
		req.Issue.Number,
		req.Issue.Title,
		req.Issue.Body,
		req.ImplementationSummary,
		getValidationStatus(req.ValidationResult.LintResult),
		getValidationStatus(req.ValidationResult.BuildResult),
		getValidationStatus(req.ValidationResult.TestResult),
	)
}

// CreateEnhancedPRDescription creates a PR description with AI or fallback
func (ci *ClaudeIntegration) CreateEnhancedPRDescription(req *types.PRDescriptionRequest) string {
	// Try to generate AI description first
	if aiDescription, err := ci.GeneratePRDescription(req); err == nil {
		return aiDescription
	}

	// Fall back to template-based description
	return ci.getFallbackPRDescription(req)
}

// getFallbackPRDescription returns a template-based PR description
func (ci *ClaudeIntegration) getFallbackPRDescription(req *types.PRDescriptionRequest) string {
	return fmt.Sprintf(`## Summary
Resolves #%d

This PR implements the requested changes for the above issue.

## Background & Context

**Original Issue:** %s

**Issue Description:**
%s

**Requirements:** Implement the functionality described in the issue above.

## Solution Approach

**Core Solution:** This PR addresses the issue by implementing the requested functionality using the existing codebase patterns and conventions.

**Technical Strategy:** The implementation follows the established architecture and coding standards of the project.

## Implementation Details

**Key Components:** The changes modify existing components and potentially add new functionality as required.

**Code Changes:** Implementation includes necessary code changes to fulfill the requirements specified in the issue.

**Integration Points:** The new functionality integrates with existing project components following established patterns.

**Error Handling:** Appropriate error handling has been implemented following project conventions.

## Technical Logic

**Implementation Logic:** The solution implements the required functionality as specified in the issue description.

**Data Flow:** Data flows through the system according to the established architectural patterns.

## Testing & Validation

**Test Strategy:** Implementation has been validated using the project's standard testing approach.

**Quality Assurance:**
- %s SwiftLint validation
- %s Swift build
- %s All tests

## Impact & Future Work

**Breaking Changes:** This implementation maintains backwards compatibility.

**Future Enhancements:** This change provides a foundation for potential future enhancements.

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>`,
		req.Issue.Number,
		req.Issue.Title,
		req.Issue.Body,
		getValidationStatusIcon(req.ValidationResult.LintResult),
		getValidationStatusIcon(req.ValidationResult.BuildResult),
		getValidationStatusIcon(req.ValidationResult.TestResult),
	)
}

// Helper functions for validation status
func getValidationStatus(result interface{}) string {
	if result == nil {
		return "➖ Skipped"
	}

	// Check if the result has a Success field
	switch v := result.(type) {
	case *types.LintResult:
		if v.Success {
			return "✅ Passed"
		}
		return "❌ Failed"
	case *types.BuildResult:
		if v.Success {
			return "✅ Passed"
		}
		return "❌ Failed"
	case *types.TestResult:
		if v.Success {
			return "✅ Passed"
		}
		return "❌ Failed"
	default:
		return "➖ Skipped"
	}
}

func getValidationStatusIcon(result interface{}) string {
	if result == nil {
		return "❌"
	}

	// Check if the result has a Success field
	switch v := result.(type) {
	case *types.LintResult:
		if v.Success {
			return "✅"
		}
		return "❌"
	case *types.BuildResult:
		if v.Success {
			return "✅"
		}
		return "❌"
	case *types.TestResult:
		if v.Success {
			return "✅"
		}
		return "❌"
	default:
		return "❌"
	}
}
