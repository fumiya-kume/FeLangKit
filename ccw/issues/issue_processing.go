package issues

import (
	"ccw/types"
	"fmt"
	"strings"
)

// GitHub issue processing and workflow management

// Additional issue processing helper functions

// Generate basic implementation context for issue processing
func generateBasicImplementationContext(issueData *types.Issue, worktreeConfig *types.WorktreeConfig) string {
	var md strings.Builder

	// Header
	md.WriteString("# Claude Code Context\n\n")
	md.WriteString("This file provides basic context for the current GitHub issue implementation.\n\n")

	// Issue Information
	md.WriteString("## 📋 Issue Information\n\n")
	md.WriteString(fmt.Sprintf("- **Issue Number**: #%d\n", issueData.Number))
	md.WriteString(fmt.Sprintf("- **Title**: %s\n", issueData.Title))
	md.WriteString(fmt.Sprintf("- **State**: %s\n", issueData.State))
	md.WriteString(fmt.Sprintf("- **URL**: %s\n", issueData.HTMLURL))

	md.WriteString("\n### Issue Description\n\n")
	md.WriteString(issueData.Body + "\n\n")

	// Development Environment
	md.WriteString("## 🛠️ Development Environment\n\n")
	md.WriteString(fmt.Sprintf("- **Branch**: %s\n", worktreeConfig.BranchName))
	md.WriteString(fmt.Sprintf("- **Worktree Path**: %s\n", worktreeConfig.WorktreePath))

	// Project Guidelines
	md.WriteString("## 📚 Project Guidelines\n\n")
	md.WriteString("Please ensure your implementation meets these quality standards:\n\n")
	md.WriteString("1. **SwiftLint Compliance**: Run `swiftlint lint --fix && swiftlint lint`\n")
	md.WriteString("2. **Build Success**: Ensure `swift build` completes without errors\n")
	md.WriteString("3. **Test Coverage**: All tests must pass with `swift test`\n")
	md.WriteString("4. **Code Style**: Follow existing project conventions and patterns\n\n")

	return md.String()
}
