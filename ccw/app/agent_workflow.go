package app

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"ccw/git"
	"ccw/github"
	"ccw/types"
)

// ExecuteWorkflowWithAgents runs the complete 8-step multi-agent development workflow
func (app *CCWApp) ExecuteWorkflowWithAgents(issueURL string) error {
	app.ui.Info("Starting 8-Step Multi-Agent Development Workflow")
	app.ui.Info(fmt.Sprintf("Processing issue: %s", issueURL))

	// Extract issue information
	owner, repo, issueNumber, err := github.ExtractIssueInfo(issueURL)
	if err != nil {
		return fmt.Errorf("failed to extract issue info: %w", err)
	}

	// Fetch issue data from GitHub
	app.ui.Info("Fetching issue data from GitHub...")
	issue, err := app.githubClient.GetIssue(owner, repo, issueNumber)
	if err != nil {
		return fmt.Errorf("failed to fetch issue data: %w", err)
	}

	// Setup development environment with git worktree
	app.ui.Info("Setting up development environment...")
	if err := app.setupAgentDevelopmentEnvironment(issue, issueNumber, owner, repo, issueURL); err != nil {
		return fmt.Errorf("failed to setup development environment: %w", err)
	}

	// === 8-STEP MULTI-AGENT PIPELINE ===
	app.ui.Info("Launching 8-Step Agent Pipeline")

	// STEP 1: Issue Analysis Agent (non-interactive Claude Code)
	app.ui.Info("STEP 1/8: Issue Analysis Agent")
	analysisResult, err := app.runIssueAnalysisAgent(issue, owner, repo)
	if err != nil {
		return fmt.Errorf("step 1 failed - issue analysis: %w", err)
	}
	app.ui.Success("Issue Analysis completed")

	// STEP 2: Implementation Agent (interactive Claude Code)
	app.ui.Info("STEP 2/8: Implementation Agent")
	if err := app.runImplementationAgent(issue, analysisResult); err != nil {
		return fmt.Errorf("step 2 failed - implementation: %w", err)
	}
	app.ui.Success("Implementation completed")

	// STEP 3: Verification + PR Review Agent
	app.ui.Info("STEP 3/8: Verification + PR Review Agent")
	verificationResult, err := app.runVerificationAndReviewAgent(issue, analysisResult)
	if err != nil {
		return fmt.Errorf("step 3 failed - verification: %w", err)
	}

	// STEP 4: Conditional Fixing Agent (if verification failed)
	if !verificationResult.Success {
		app.ui.Warning("STEP 4/8: Fixing Agent (verification issues detected)")
		if err := app.runFixingAgent(issue, analysisResult, verificationResult); err != nil {
			return fmt.Errorf("step 4 failed - fixing: %w", err)
		}

		// Re-verify after fixes
		app.ui.Info("Re-running verification after fixes...")
		verificationResult, err = app.runVerificationAndReviewAgent(issue, analysisResult)
		if err != nil {
			return fmt.Errorf("re-verification failed: %w", err)
		}
	}

	// Only proceed if verification passes
	if !verificationResult.Success {
		return fmt.Errorf("verification failed after fixing attempts - manual intervention required")
	}
	app.ui.Success("Verification and review completed")

	// STEP 5: Commit Agent (small, meaningful commits)
	app.ui.Info("STEP 5/8: Commit Agent")
	if err := app.runCommitAgent(issue, analysisResult); err != nil {
		return fmt.Errorf("step 5 failed - commit: %w", err)
	}
	app.ui.Success("Commits created")

	// STEP 6: PR Description Agent (non-interactive Claude Code)
	app.ui.Info("STEP 6/8: PR Description Agent")
	prTitle, prDescription, err := app.runPRDescriptionAgent(issue, analysisResult)
	if err != nil {
		return fmt.Errorf("step 6 failed - PR description: %w", err)
	}
	app.ui.Success("PR description generated")

	// STEP 7: PR Creation with gh command (Golang program)
	app.ui.Info("STEP 7/8: PR Creation")
	if err := app.runPRCreationWithGH(prTitle, prDescription); err != nil {
		return fmt.Errorf("step 7 failed - PR creation: %w", err)
	}
	app.ui.Success("PR created successfully")

	// STEP 8: PR Monitoring + Auto-Fix Agent
	app.ui.Info("STEP 8/8: PR Monitoring + Auto-Fix Agent")
	if err := app.runPRMonitoringAgent(issue, owner, repo); err != nil {
		return fmt.Errorf("step 8 failed - PR monitoring: %w", err)
	}

	app.ui.Success("8-Step Agent Workflow completed successfully!")
	app.ui.Info(fmt.Sprintf("PR URL: %s", app.currentPRURL))

	return nil
}

// setupAgentDevelopmentEnvironment sets up the git worktree and project environment for agent workflow
func (app *CCWApp) setupAgentDevelopmentEnvironment(issue *types.Issue, issueNumber int, owner, repo, issueURL string) error {
	// Generate branch name
	branchName := fmt.Sprintf("issue-%d-%s", issueNumber, time.Now().Format("20060102-150405"))
	worktreePath := filepath.Join(app.config.WorktreeBase, branchName)

	// Set up worktree config
	app.worktreeConfig = &git.WorktreeConfig{
		BasePath:     app.config.WorktreeBase,
		BranchName:   branchName,
		WorktreePath: worktreePath,
		IssueNumber:  issueNumber,
		CreatedAt:    time.Now(),
		Owner:        owner,
		Repository:   repo,
		IssueURL:     issueURL,
	}

	// Create git worktree
	if err := app.gitOps.CreateWorktree(branchName, worktreePath); err != nil {
		return fmt.Errorf("failed to create git worktree: %w", err)
	}

	// Setup Claude Code permissions for seamless automation
	if err := app.setupClaudePermissions(worktreePath); err != nil {
		app.logger.Error("workflow", "Failed to setup Claude permissions", map[string]interface{}{
			"worktree_path": worktreePath,
			"error":         err.Error(),
		})
		// Continue anyway - this is not a critical failure
		app.ui.Warning("Claude permissions setup failed, Claude Code may require manual permission confirmations")
	} else {
		app.ui.Info("Claude Code permissions configured for seamless automation")
	}

	// Update agent executor with worktree path
	app.agentExecutor.SetWorkingDirectory(worktreePath)

	// Save issue data to context file for agents
	if err := app.saveAgentIssueContext(issue, owner, repo, issueURL); err != nil {
		return fmt.Errorf("failed to save issue context: %w", err)
	}

	return nil
}

// saveAgentIssueContext saves the issue context to files for agent reference
func (app *CCWApp) saveAgentIssueContext(issue *types.Issue, owner, repo, issueURL string) error {
	// Create ClaudeContext with proper field names
	contextData := &types.ClaudeContext{
		IssueData: issue,
		WorktreeConfig: &types.WorktreeConfig{
			BasePath:     app.worktreeConfig.BasePath,
			BranchName:   app.worktreeConfig.BranchName,
			WorktreePath: app.worktreeConfig.WorktreePath,
			IssueNumber:  app.worktreeConfig.IssueNumber,
			CreatedAt:    app.worktreeConfig.CreatedAt,
			Owner:        owner,
			Repository:   repo,
			IssueURL:     issueURL,
		},
		ProjectPath: app.worktreeConfig.WorktreePath,
		TaskType:    "agent_workflow",
	}

	// Save context as JSON for programmatic access
	if err := app.saveClaudeContextJSON(contextData); err != nil {
		return fmt.Errorf("failed to save context JSON: %w", err)
	}

	// Save context as Markdown for Claude Code agents
	if err := app.saveClaudeContextMarkdown(contextData); err != nil {
		return fmt.Errorf("failed to save context Markdown: %w", err)
	}

	return nil
}

// saveClaudeContextJSON saves the Claude context as a JSON file
func (app *CCWApp) saveClaudeContextJSON(ctx *types.ClaudeContext) error {
	contextPath := filepath.Join(app.worktreeConfig.WorktreePath, ".claude-context.json")
	data, err := json.MarshalIndent(ctx, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal context: %w", err)
	}
	return os.WriteFile(contextPath, data, 0644)
}

// saveClaudeContextMarkdown saves the Claude context as a Markdown file
func (app *CCWApp) saveClaudeContextMarkdown(ctx *types.ClaudeContext) error {
	contextPath := filepath.Join(app.worktreeConfig.WorktreePath, ".claude-context.md")
	md := app.generateContextMarkdown(ctx)
	return os.WriteFile(contextPath, []byte(md), 0644)
}

// generateContextMarkdown generates a markdown representation of the context
func (app *CCWApp) generateContextMarkdown(ctx *types.ClaudeContext) string {
	var md strings.Builder

	md.WriteString("# Claude Code Agent Context\n\n")

	if ctx.IssueData != nil {
		md.WriteString(fmt.Sprintf("## Issue #%d: %s\n\n", ctx.IssueData.Number, ctx.IssueData.Title))
		md.WriteString("### Description\n\n")
		md.WriteString(ctx.IssueData.Body + "\n\n")

		if len(ctx.IssueData.Labels) > 0 {
			md.WriteString("### Labels\n")
			for _, label := range ctx.IssueData.Labels {
				md.WriteString(fmt.Sprintf("- %s\n", label.Name))
			}
			md.WriteString("\n")
		}
	}

	if ctx.WorktreeConfig != nil {
		md.WriteString("## Development Environment\n\n")
		md.WriteString(fmt.Sprintf("- **Branch**: %s\n", ctx.WorktreeConfig.BranchName))
		md.WriteString(fmt.Sprintf("- **Worktree Path**: %s\n", ctx.WorktreeConfig.WorktreePath))
		md.WriteString(fmt.Sprintf("- **Owner**: %s\n", ctx.WorktreeConfig.Owner))
		md.WriteString(fmt.Sprintf("- **Repository**: %s\n", ctx.WorktreeConfig.Repository))
		md.WriteString("\n")
	}

	md.WriteString("## Project Guidelines\n\n")
	md.WriteString("Please ensure your implementation meets these quality standards:\n\n")
	md.WriteString("1. **SwiftLint Compliance**: Run `swiftlint lint --fix && swiftlint lint`\n")
	md.WriteString("2. **Build Success**: Ensure `swift build` completes without errors\n")
	md.WriteString("3. **Test Coverage**: All tests must pass with `swift test`\n")
	md.WriteString("4. **Code Style**: Follow existing project conventions and patterns\n\n")

	return md.String()
}
