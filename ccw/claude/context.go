package claude

import (
	"fmt"
	"strings"

	"ccw/types"
)

// generateMarkdownContext creates comprehensive markdown context file
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
