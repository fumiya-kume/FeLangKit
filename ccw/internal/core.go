package internal

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"time"

	"ccw/pkg/claude"
)

// Config represents the application configuration
type Config struct {
	WorktreeBase    string        `yaml:"worktree_base"`
	ClaudeTimeout   time.Duration `yaml:"claude_timeout"`
	MaxRetries      int           `yaml:"max_retries"`
	DebugMode       bool          `yaml:"debug_mode"`
	ValidateChanges bool          `yaml:"validate_changes"`
}

// WorktreeConfig stores worktree-specific information
type WorktreeConfig struct {
	IssueNumber int    `json:"issue_number"`
	IssueURL    string `json:"issue_url"`
	BranchName  string `json:"branch_name"`
	WorktreePath string `json:"worktree_path"`
	CreatedAt   time.Time `json:"created_at"`
}

// ProcessIssue is the main workflow entry point
func ProcessIssue(issueURL, mode string) {
	// Debug and verbose modes can be used for future enhancements
	_ = mode // Silence unused variable warning

	// Initialize components
	ui := NewUI()
	config := loadConfig()
	gitOps := NewGitOperations(getRepoRoot())
	githubClient := NewGitHubClient()
	claudeClient := claude.NewClient(config.ClaudeTimeout)

	// Show startup message
	ui.ShowStartup(issueURL)

	// Step 1: Validate environment
	ui.UpdateStatus("Validating environment...")
	if err := validateEnvironment(gitOps, githubClient); err != nil {
		ui.ShowError("Environment validation failed", err)
		return
	}

	// Step 2: Fetch issue details
	ui.UpdateStatus("Fetching issue details...")
	issue, err := githubClient.FetchIssue(issueURL)
	if err != nil {
		ui.ShowError("Failed to fetch issue", err)
		return
	}
	ui.ShowIssueInfo(issue.Number, issue.Title)

	// Step 3: Create worktree
	branchName := fmt.Sprintf("issue-%d-%s", issue.Number, time.Now().Format("20060102-150405"))
	worktreePath := filepath.Join(config.WorktreeBase, branchName)
	
	ui.UpdateStatus("Creating worktree...")
	if err := gitOps.CreateWorktree(worktreePath, branchName); err != nil {
		ui.ShowError("Failed to create worktree", err)
		return
	}

	// Save worktree config
	worktreeConfig := &WorktreeConfig{
		IssueNumber:  issue.Number,
		IssueURL:     issueURL,
		BranchName:   branchName,
		WorktreePath: worktreePath,
		CreatedAt:    time.Now(),
	}
	saveWorktreeConfig(worktreePath, worktreeConfig)

	// Step 4: Launch Claude Code
	ui.UpdateStatus("Launching Claude Code...")
	claudeContext := buildClaudeContext(issue, worktreePath)
	
	if err := claudeClient.LaunchInteractive(worktreePath, claudeContext); err != nil {
		ui.ShowError("Claude Code session failed", err)
		cleanupWorktree(gitOps, worktreePath)
		return
	}

	// Step 5: Check for changes
	ui.UpdateStatus("Checking for changes...")
	hasChanges, err := gitOps.HasUncommittedChanges(worktreePath)
	if err != nil {
		ui.ShowError("Failed to check changes", err)
		return
	}

	if !hasChanges {
		ui.ShowWarning("No changes detected")
		cleanupWorktree(gitOps, worktreePath)
		return
	}

	// Step 6: Validate changes (if enabled)
	if config.ValidateChanges {
		ui.UpdateStatus("Validating implementation...")
		result, err := ValidateImplementation(worktreePath)
		if err != nil || !result.LintPassed || !result.BuildPassed || !result.TestsPassed {
			ui.ShowValidationResults(result)
			if !ui.ConfirmContinue("Validation failed. Continue anyway?") {
				cleanupWorktree(gitOps, worktreePath)
				return
			}
		}
	}

	// Step 7: Commit changes
	ui.UpdateStatus("Generating commit message...")
	commitMsg, err := gitOps.GenerateCommitMessage(worktreePath)
	if err != nil {
		commitMsg = fmt.Sprintf("fix: resolve issue #%d", issue.Number)
	}

	if err := gitOps.CommitChanges(worktreePath, commitMsg); err != nil {
		ui.ShowError("Failed to commit changes", err)
		return
	}

	// Step 8: Push branch
	ui.UpdateStatus("Pushing branch...")
	if err := gitOps.PushBranch(worktreePath, branchName); err != nil {
		ui.ShowError("Failed to push branch", err)
		return
	}

	// Step 9: Create PR
	ui.UpdateStatus("Creating pull request...")
	prTitle := fmt.Sprintf("Resolve #%d: %s", issue.Number, issue.Title)
	prBody := githubClient.GeneratePRDescription(issue, []string{commitMsg})
	
	pr, err := githubClient.CreatePullRequest(prTitle, prBody, branchName)
	if err != nil {
		ui.ShowError("Failed to create PR", err)
		return
	}

	ui.ShowPRCreated(pr.URL)

	// Step 10: Wait for CI checks
	ui.UpdateStatus("Waiting for CI checks...")
	if err := githubClient.WaitForPRChecks(pr.URL); err != nil {
		ui.ShowError("CI checks failed", err)
		return
	}

	ui.ShowSuccess("Workflow completed successfully!")
}

// Helper functions

func loadConfig() *Config {
	// Default config
	config := &Config{
		WorktreeBase:    ".ccw-worktrees",
		ClaudeTimeout:   30 * time.Minute,
		MaxRetries:      3,
		DebugMode:       false,
		ValidateChanges: true,
	}

	// Try to load from file
	if _, err := ioutil.ReadFile("ccw.yaml"); err == nil {
		// Parse YAML config (simplified for now)
		// TODO: Implement proper YAML parsing
	}

	return config
}

func validateEnvironment(gitOps *GitOperations, githubClient *GitHubClient) error {
	// Check git repository
	if err := gitOps.ValidateRepository(); err != nil {
		return err
	}

	// Check GitHub CLI
	if err := githubClient.CheckGHCLI(); err != nil {
		return err
	}

	// Check Swift tools
	if _, err := os.Stat("Package.swift"); err == nil {
		// This is a Swift project, check tools
		if err := checkCommand("swift"); err != nil {
			return fmt.Errorf("Swift not found: %w", err)
		}
		if err := checkCommand("swiftlint"); err != nil {
			log.Println("Warning: SwiftLint not found, validation will be limited")
		}
	}

	return nil
}

func checkCommand(name string) error {
	_, err := os.Stat(fmt.Sprintf("/usr/bin/%s", name))
	if err != nil {
		_, err = os.Stat(fmt.Sprintf("/usr/local/bin/%s", name))
	}
	return err
}

func getRepoRoot() string {
	// Find git repository root
	cwd, _ := os.Getwd()
	return cwd // Simplified, should walk up to find .git
}

func buildClaudeContext(issue *Issue, worktreePath string) string {
	return fmt.Sprintf(`You are working on GitHub issue #%d: %s

Issue Description:
%s

Working Directory: %s

Please implement the necessary changes to resolve this issue. Make sure to:
1. Understand the issue requirements
2. Implement the solution
3. Add appropriate tests
4. Ensure all existing tests pass
5. Follow the project's coding standards

When you're done, I'll help you create a pull request.`, 
		issue.Number, issue.Title, issue.Body, worktreePath)
}

func saveWorktreeConfig(worktreePath string, config *WorktreeConfig) {
	configPath := filepath.Join(worktreePath, ".worktree-config.json")
	data, _ := json.MarshalIndent(config, "", "  ")
	ioutil.WriteFile(configPath, data, 0644)
}

func cleanupWorktree(gitOps *GitOperations, worktreePath string) {
	gitOps.RemoveWorktree(worktreePath)
}

// Additional workflow commands

func ListWorktrees() {
	gitOps := NewGitOperations(getRepoRoot())
	worktrees, err := gitOps.ListWorktrees()
	if err != nil {
		log.Fatalf("Failed to list worktrees: %v", err)
	}

	if len(worktrees) == 0 {
		fmt.Println("No active worktrees found.")
		return
	}

	fmt.Println("Active worktrees:")
	for _, wt := range worktrees {
		// Try to read worktree config
		configPath := filepath.Join(wt, ".worktree-config.json")
		if data, err := ioutil.ReadFile(configPath); err == nil {
			var config WorktreeConfig
			if json.Unmarshal(data, &config) == nil {
				fmt.Printf("  - %s (Issue #%d, created %s)\n", 
					config.BranchName, config.IssueNumber, 
					config.CreatedAt.Format("2006-01-02 15:04"))
				continue
			}
		}
		fmt.Printf("  - %s\n", wt)
	}
}

func CleanupAllWorktrees() {
	gitOps := NewGitOperations(getRepoRoot())
	worktrees, err := gitOps.ListWorktrees()
	if err != nil {
		log.Fatalf("Failed to list worktrees: %v", err)
	}

	if len(worktrees) == 0 {
		fmt.Println("No worktrees to clean up.")
		return
	}

	fmt.Printf("Removing %d worktrees...\n", len(worktrees))
	for _, wt := range worktrees {
		if err := gitOps.RemoveWorktree(wt); err != nil {
			log.Printf("Failed to remove %s: %v", wt, err)
		} else {
			fmt.Printf("  ✓ Removed %s\n", wt)
		}
	}
}

func RunDiagnostics() {
	fmt.Println("CCW System Diagnostics")
	fmt.Println("=====================")
	
	// Check git
	gitOps := NewGitOperations(getRepoRoot())
	if err := gitOps.ValidateRepository(); err != nil {
		fmt.Println("❌ Git repository: Not found")
	} else {
		fmt.Println("✅ Git repository: OK")
	}

	// Check GitHub CLI
	githubClient := NewGitHubClient()
	if err := githubClient.CheckGHCLI(); err != nil {
		fmt.Printf("❌ GitHub CLI: %v\n", err)
	} else {
		fmt.Println("✅ GitHub CLI: Authenticated")
	}

	// Check Swift tools
	if _, err := os.Stat("Package.swift"); err == nil {
		if err := checkCommand("swift"); err != nil {
			fmt.Println("❌ Swift: Not found")
		} else {
			fmt.Println("✅ Swift: Available")
		}

		if err := checkCommand("swiftlint"); err != nil {
			fmt.Println("⚠️  SwiftLint: Not found (optional)")
		} else {
			fmt.Println("✅ SwiftLint: Available")
		}
	}

	// Check Claude
	if err := checkCommand("claude"); err != nil {
		fmt.Println("❌ Claude Code CLI: Not found")
	} else {
		fmt.Println("✅ Claude Code CLI: Available")
	}
}

func GenerateSampleConfig(filename string) error {
	sample := `# CCW Configuration File
worktree_base: .ccw-worktrees
claude_timeout: 30m
max_retries: 3
debug_mode: false
validate_changes: true

# UI theme (dark, light, auto)
ui_theme: auto

# Git settings
git:
  auto_commit: true
  commit_style: conventional
  
# Validation settings  
validation:
  run_linter: true
  run_tests: true
  run_build: true
`
	return ioutil.WriteFile(filename, []byte(sample), 0644)
}