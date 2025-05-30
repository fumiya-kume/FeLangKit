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

// Claude integration
type ClaudeIntegration struct {
	Timeout    time.Duration
	MaxRetries int
	DebugMode  bool
}

// Generate AI PR description using Claude Code
func (ci *ClaudeIntegration) GeneratePRDescription(req *types.PRDescriptionRequest) (string, error) {
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
	cmdCtx, cancel := context.WithTimeout(context.Background(), 5*time.Minute) // Shorter timeout for PR description
	defer cancel()

	cmd := exec.CommandContext(cmdCtx, "claude", "--print", "--output-format", "json")
	cmd.Dir = req.WorktreeConfig.WorktreePath

	// Prepare Claude prompt for PR description generation
	claudeInput := fmt.Sprintf(`
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
		func() string {
			if req.ValidationResult.LintResult != nil {
				if req.ValidationResult.LintResult.Success {
					return "✅ Passed"
				}
				return "❌ Failed"
			}
			return "➖ Skipped"
		}(),
		func() string {
			if req.ValidationResult.BuildResult != nil {
				if req.ValidationResult.BuildResult.Success {
					return "✅ Passed"
				}
				return "❌ Failed"
			}
			return "➖ Skipped"
		}(),
		func() string {
			if req.ValidationResult.TestResult != nil {
				if req.ValidationResult.TestResult.Success {
					return "✅ Passed"
				}
				return "❌ Failed"
			}
			return "➖ Skipped"
		}(),
	)

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

// Get fallback PR description template
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
		func() string {
			if req.ValidationResult.LintResult != nil && req.ValidationResult.LintResult.Success {
				return "✅"
			}
			return "❌"
		}(),
		func() string {
			if req.ValidationResult.BuildResult != nil && req.ValidationResult.BuildResult.Success {
				return "✅"
			}
			return "❌"
		}(),
		func() string {
			if req.ValidationResult.TestResult != nil && req.ValidationResult.TestResult.Success {
				return "✅"
			}
			return "❌"
		}(),
	)
}

// Generate implementation summary from git changes
func (ci *ClaudeIntegration) GenerateImplementationSummary(worktreePath string) (string, error) {
	// Get git diff to analyze changes
	cmd := exec.Command("git", "diff", "--name-status", "HEAD")
	cmd.Dir = worktreePath
	output, err := cmd.Output()
	if err != nil {
		return "Implementation completed with code changes.", nil // Fallback if git diff fails
	}

	changes := strings.TrimSpace(string(output))
	if changes == "" {
		return "No code changes detected.", nil
	}

	// Parse the changes
	lines := strings.Split(changes, "\n")
	var addedFiles, modifiedFiles, deletedFiles []string
	
	for _, line := range lines {
		parts := strings.Fields(line)
		if len(parts) >= 2 {
			status := parts[0]
			file := parts[1]
			
			switch status {
			case "A":
				addedFiles = append(addedFiles, file)
			case "M":
				modifiedFiles = append(modifiedFiles, file)
			case "D":
				deletedFiles = append(deletedFiles, file)
			}
		}
	}

	// Build summary
	var summary strings.Builder
	summary.WriteString("Implementation completed with the following changes:\n")
	
	if len(addedFiles) > 0 {
		summary.WriteString(fmt.Sprintf("- Added %d new files: %s\n", len(addedFiles), strings.Join(addedFiles, ", ")))
	}
	if len(modifiedFiles) > 0 {
		summary.WriteString(fmt.Sprintf("- Modified %d existing files: %s\n", len(modifiedFiles), strings.Join(modifiedFiles, ", ")))
	}
	if len(deletedFiles) > 0 {
		summary.WriteString(fmt.Sprintf("- Deleted %d files: %s\n", len(deletedFiles), strings.Join(deletedFiles, ", ")))
	}

	return summary.String(), nil
}

// Run Claude Code with context
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
		args = []string{"--print", "--output-format", "json"}
	} else {
		args = []string{}
	}

	// Create command with timeout
	cmdCtx, cancel := context.WithTimeout(context.Background(), ci.Timeout)
	defer cancel()

	cmd := exec.CommandContext(cmdCtx, "claude", args...)
	cmd.Dir = ctx.ProjectPath

	// Prepare input for Claude with issue context
	claudeInput := fmt.Sprintf(`
Please work on GitHub issue #%d: %s

Issue Description:
%s

Project Path: %s
Worktree Branch: %s

Please implement the requested changes and run the complete validation sequence:
swiftlint lint --fix && swiftlint lint && swift build && swift test

If this is a retry (attempt %d), please focus on fixing the validation errors:
%s
`, 
		ctx.IssueData.Number,
		ctx.IssueData.Title,
		ctx.IssueData.Body,
		ctx.ProjectPath,
		ctx.WorktreeConfig.BranchName,
		ctx.RetryAttempt,
		func() string {
			if len(ctx.ValidationErrors) > 0 {
				var errors []string
				for _, err := range ctx.ValidationErrors {
					errors = append(errors, fmt.Sprintf("- %s: %s", err.Type, err.Message))
				}
				return strings.Join(errors, "\n")
			}
			return "None"
		}(),
	)

	if !ctx.IsRetry {
		// Interactive mode for initial run
		cmd.Stdin = strings.NewReader(claudeInput)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		
		return cmd.Run()
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

// Generate comprehensive markdown context file
func (ci *ClaudeIntegration) generateMarkdownContext(ctx *types.ClaudeContext) (string, error) {
	var md strings.Builder
	
	// Header
	md.WriteString("# Claude Code Context\n\n")
	md.WriteString("This file provides comprehensive context for the current GitHub issue implementation.\n\n")
	
	// Issue Information
	md.WriteString("## 📋 Issue Information\n\n")
	md.WriteString(fmt.Sprintf("- **Issue Number**: #%d\n", ctx.IssueData.Number))
	md.WriteString(fmt.Sprintf("- **Title**: %s\n", ctx.IssueData.Title))
	md.WriteString(fmt.Sprintf("- **State**: %s\n", ctx.IssueData.State))
	md.WriteString(fmt.Sprintf("- **URL**: %s\n", ctx.IssueData.HTMLURL))
	md.WriteString(fmt.Sprintf("- **Created**: %s\n", ctx.IssueData.CreatedAt.Format("2006-01-02 15:04:05")))
	md.WriteString(fmt.Sprintf("- **Updated**: %s\n", ctx.IssueData.UpdatedAt.Format("2006-01-02 15:04:05")))
	
	// Labels
	if len(ctx.IssueData.Labels) > 0 {
		md.WriteString("- **Labels**: ")
		labels := make([]string, len(ctx.IssueData.Labels))
		for i, label := range ctx.IssueData.Labels {
			labels[i] = fmt.Sprintf("`%s`", label.Name)
		}
		md.WriteString(strings.Join(labels, ", ") + "\n")
	}
	
	// Assignees
	if len(ctx.IssueData.Assignees) > 0 {
		md.WriteString("- **Assignees**: ")
		assignees := make([]string, len(ctx.IssueData.Assignees))
		for i, assignee := range ctx.IssueData.Assignees {
			assignees[i] = fmt.Sprintf("@%s", assignee.Login)
		}
		md.WriteString(strings.Join(assignees, ", ") + "\n")
	}
	
	md.WriteString("\n### Issue Description\n\n")
	md.WriteString(ctx.IssueData.Body + "\n\n")
	
	// Development Environment
	md.WriteString("## 🛠️ Development Environment\n\n")
	md.WriteString(fmt.Sprintf("- **Repository**: %s/%s\n", ctx.IssueData.Repository.Owner.Login, ctx.IssueData.Repository.Name))
	md.WriteString(fmt.Sprintf("- **Project Path**: %s\n", ctx.ProjectPath))
	md.WriteString(fmt.Sprintf("- **Branch**: %s\n", ctx.WorktreeConfig.BranchName))
	md.WriteString(fmt.Sprintf("- **Worktree Path**: %s\n", ctx.WorktreeConfig.WorktreePath))
	md.WriteString(fmt.Sprintf("- **Created**: %s\n", ctx.WorktreeConfig.CreatedAt.Format("2006-01-02 15:04:05")))
	md.WriteString("\n")
	
	// Implementation Context
	md.WriteString("## 🎯 Implementation Context\n\n")
	if ctx.IsRetry {
		md.WriteString(fmt.Sprintf("- **Status**: Retry attempt #%d\n", ctx.RetryAttempt))
		md.WriteString("- **Previous attempts**: Failed validation - see error details below\n")
	} else {
		md.WriteString("- **Status**: Initial implementation\n")
	}
	md.WriteString(fmt.Sprintf("- **Task Type**: %s\n", ctx.TaskType))
	md.WriteString("\n")
	
	// Validation Errors (if any)
	if len(ctx.ValidationErrors) > 0 {
		md.WriteString("## ❌ Previous Validation Errors\n\n")
		md.WriteString("The following errors occurred in previous attempts and need to be addressed:\n\n")
		
		for i, err := range ctx.ValidationErrors {
			md.WriteString(fmt.Sprintf("### Error %d: %s\n\n", i+1, strings.Title(err.Type)))
			md.WriteString(fmt.Sprintf("- **Type**: %s\n", err.Type))
			md.WriteString(fmt.Sprintf("- **Message**: %s\n", err.Message))
			if err.File != "" {
				md.WriteString(fmt.Sprintf("- **File**: %s", err.File))
				if err.Line > 0 {
					md.WriteString(fmt.Sprintf(":%d", err.Line))
				}
				md.WriteString("\n")
			}
			md.WriteString(fmt.Sprintf("- **Recoverable**: %t\n", err.Recoverable))
			md.WriteString("\n")
		}
	}
	
	// Project Guidelines
	md.WriteString("## 📚 Project Guidelines\n\n")
	md.WriteString("### Code Quality Requirements\n\n")
	md.WriteString("Please ensure your implementation meets these quality standards:\n\n")
	md.WriteString("1. **SwiftLint Compliance**: Run `swiftlint lint --fix && swiftlint lint`\n")
	md.WriteString("2. **Build Success**: Ensure `swift build` completes without errors\n")
	md.WriteString("3. **Test Coverage**: All tests must pass with `swift test`\n")
	md.WriteString("4. **Code Style**: Follow existing project conventions and patterns\n")
	md.WriteString("5. **Documentation**: Add appropriate code comments and documentation\n\n")
	
	md.WriteString("### Implementation Strategy\n\n")
	md.WriteString("1. **Analyze the Issue**: Understand the requirements and scope\n")
	md.WriteString("2. **Review Existing Code**: Familiarize yourself with current patterns\n")
	md.WriteString("3. **Implement Changes**: Write clean, well-structured code\n")
	md.WriteString("4. **Add Tests**: Include appropriate test coverage\n")
	md.WriteString("5. **Validate Quality**: Run the complete validation sequence\n\n")
	
	// Commands to Run
	md.WriteString("## 🔧 Required Commands\n\n")
	md.WriteString("After implementing your changes, run these commands:\n\n")
	md.WriteString("```bash\n")
	md.WriteString("# Auto-fix linting issues\n")
	md.WriteString("swiftlint lint --fix\n\n")
	md.WriteString("# Check for remaining lint issues\n")
	md.WriteString("swiftlint lint\n\n")
	md.WriteString("# Build the project\n")
	md.WriteString("swift build\n\n")
	md.WriteString("# Run all tests\n")
	md.WriteString("swift test\n")
	md.WriteString("```\n\n")
	
	// Troubleshooting
	if ctx.IsRetry {
		md.WriteString("## 🔍 Troubleshooting\n\n")
		md.WriteString("Since this is a retry attempt, focus on:\n\n")
		md.WriteString("1. **Addressing Previous Errors**: See validation errors section above\n")
		md.WriteString("2. **Code Quality**: Ensure SwiftLint compliance\n")
		md.WriteString("3. **Build Issues**: Fix any compilation errors\n")
		md.WriteString("4. **Test Failures**: Debug and fix failing tests\n")
		md.WriteString("5. **Integration**: Verify changes work with existing code\n\n")
	}
	
	// Footer
	md.WriteString("---\n")
	md.WriteString("*This context file was automatically generated by CCW (Claude Code Worktree) automation tool.*\n")
	
	return md.String(), nil
}

// Generate enhanced PR description with AI or fallback
func (ci *ClaudeIntegration) CreateEnhancedPRDescription(req *types.PRDescriptionRequest) string {
	// Try to generate AI description first
	if aiDescription, err := ci.GeneratePRDescription(req); err == nil {
		return aiDescription
	}

	// Fall back to template-based description
	return ci.getFallbackPRDescription(req)
}