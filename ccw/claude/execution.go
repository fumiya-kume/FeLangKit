package claude

import (
	"context"
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

// buildClaudeInput creates the input prompt for Claude Code
func (ci *ClaudeIntegration) buildClaudeInput(ctx *types.ClaudeContext) string {
	return fmt.Sprintf(`
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
		formatValidationErrors(ctx.ValidationErrors),
	)
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