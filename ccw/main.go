package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"ccw/claude"
	"ccw/config"
	"ccw/git"
	"ccw/github"
	"ccw/logging"
	"ccw/types"
	"ccw/ui"
)

// Use existing types from other files - no need to redefine them

// Updated application struct using new packages
type CCWApp struct {
	config            *config.Config
	gitOps            *git.Operations
	validator         *git.QualityValidator
	worktreeConfig    *git.WorktreeConfig
	sessionID         string
	
	// Use types from packages
	githubClient      *github.GitHubClient
	claudeIntegration *claude.ClaudeIntegration
	ui                *ui.UIManager
	logger            *logging.Logger
	errorStore        *types.ErrorStore
}

// Initialize the application with new package structure
func NewCCWApp() (*CCWApp, error) {
	// Generate session ID
	sessionID := fmt.Sprintf("%d-%s", time.Now().Unix(), generateRandomID(8))
	
	// Load configuration using config package
	ccwConfig, err := config.LoadConfiguration()
	if err != nil {
		return nil, fmt.Errorf("failed to load configuration: %w", err)
	}
	
	// Validate configuration
	if err := ccwConfig.Validate(); err != nil {
		return nil, fmt.Errorf("invalid configuration: %w", err)
	}
	
	// Convert to legacy config format for backward compatibility
	legacyConfig := ccwConfig.ToLegacyConfig()

	// Check if gh CLI is available and authenticated
	if err := github.CheckGHCLI(); err != nil {
		return nil, fmt.Errorf("GitHub CLI (gh) is required: %w", err)
	}

	// Initialize git operations with new package
	gitConfig := &git.GitOperationConfig{
		Timeout:       parseTimeoutFromConfig(ccwConfig.Git.Timeout),
		RetryAttempts: ccwConfig.Git.RetryAttempts,
		RetryDelay:    parseTimeoutFromConfig(ccwConfig.Git.RetryDelay),
	}
	gitOps := git.NewOperations(ccwConfig.WorktreeBase, gitConfig, legacyConfig)

	// Initialize git validator
	validator := git.NewQualityValidator()

	// Initialize components using packages
	githubClient := &github.GitHubClient{}
	
	timeout, _ := time.ParseDuration(ccwConfig.ClaudeTimeout)
	claudeIntegration := &claude.ClaudeIntegration{
		Timeout:    timeout,
		MaxRetries: ccwConfig.MaxRetries,
		DebugMode:  ccwConfig.DebugMode,
	}

	uiManager := &ui.UIManager{
		Theme:      ccwConfig.UI.Theme,
		Animations: ccwConfig.UI.Animations,
		DebugMode:  ccwConfig.DebugMode,
	}
	uiManager.InitializeColors()
	uiManager.InitializeProgress()

	// Initialize logger
	enableFileLogging := ccwConfig.DebugMode || getEnvWithDefault("CCW_LOG_FILE", "false") == "true"
	logger, err := logging.NewLogger(sessionID, enableFileLogging)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize logger: %w", err)
	}

	// Initialize error store
	errorStore, err := types.NewErrorStore(sessionID)
	if err != nil {
		logger.Close()
		return nil, fmt.Errorf("failed to initialize error store: %w", err)
	}

	logger.Info("application", "CCW application initialized", map[string]interface{}{
		"session_id": sessionID,
		"debug_mode": ccwConfig.DebugMode,
		"theme":      ccwConfig.UI.Theme,
	})

	return &CCWApp{
		config:            legacyConfig,
		gitOps:            gitOps,
		validator:         validator,
		githubClient:      githubClient,
		claudeIntegration: claudeIntegration,
		ui:                uiManager,
		logger:            logger,
		errorStore:        errorStore,
		sessionID:         sessionID,
	}, nil
}

// Updated workflow execution using new packages
func (app *CCWApp) executeWorkflow(issueURL string) error {
	if app.ui.animations {
		app.ui.displayProgressHeader()
	} else {
		app.ui.displayHeader()
	}

	// Step 1: Extract issue info
	app.ui.UpdateProgress("setup", "in_progress")
	owner, repo, issueNumber, err := github.ExtractIssueInfo(issueURL)
	if err != nil {
		return fmt.Errorf("failed to extract issue info: %w", err)
	}

	app.ui.info(fmt.Sprintf("Processing issue #%d from %s/%s", issueNumber, owner, repo))

	// Step 2: Fetch issue data
	app.ui.UpdateProgress("fetch", "in_progress")
	app.ui.info("Fetching GitHub issue data...")
	
	issue, err := app.githubClient.GetIssue(owner, repo, issueNumber)
	if err != nil {
		app.ui.UpdateProgress("fetch", "failed")
		return fmt.Errorf("failed to fetch issue data: %w", err)
	}
	app.ui.UpdateProgress("fetch", "completed")

	// Step 3: Create worktree configuration using git package
	app.ui.info("Creating isolated development environment...")
	branchName := generateBranchName(issueNumber)
	worktreePath := filepath.Join(app.config.WorktreeBase, branchName)
	
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

	// Create git worktree using new package
	if err := app.gitOps.CreateWorktree(branchName, worktreePath); err != nil {
		app.ui.UpdateProgress("setup", "failed")
		return fmt.Errorf("failed to create worktree: %w", err)
	}
	app.ui.UpdateProgress("setup", "completed")

	// Save issue and worktree data
	issueDataFile := filepath.Join(worktreePath, ".issue-data.json")
	issueData, _ := json.MarshalIndent(issue, "", "  ")
	os.WriteFile(issueDataFile, issueData, 0644)

	worktreeDataFile := filepath.Join(worktreePath, ".worktree-config.json")
	worktreeData, _ := json.MarshalIndent(app.worktreeConfig, "", "  ")
	os.WriteFile(worktreeDataFile, worktreeData, 0644)

	// Implementation and validation steps...
	app.ui.UpdateProgress("implementation", "in_progress")
	app.ui.info("Running implementation...")
	
	// Run Claude Code (simplified for demo)
	claudeCtx := &claude.ClaudeContext{
		IssueData:      issue,
		WorktreeConfig: app.worktreeConfig,
		ProjectPath:    worktreePath,
		TaskType:       "implementation",
	}
	
	if err := app.claudeIntegration.RunWithContext(claudeCtx); err != nil {
		app.ui.warning(fmt.Sprintf("Claude Code execution warning: %v", err))
	}
	app.ui.UpdateProgress("implementation", "completed")

	// Validation using git package
	app.ui.UpdateProgress("validation", "in_progress")
	app.ui.info("Validating implementation...")
	
	validationResult, err := app.validator.ValidateImplementation(worktreePath)
	if err != nil {
		app.ui.UpdateProgress("validation", "failed")
		return fmt.Errorf("validation error: %w", err)
	}

	if validationResult.Success {
		app.ui.UpdateProgress("validation", "completed")
		app.ui.success("Implementation validation successful!")
		
		// Push changes using git package
		app.ui.info("Pushing changes...")
		if err := app.gitOps.PushBranch(worktreePath, branchName); err != nil {
			return fmt.Errorf("failed to push changes: %w", err)
		}
		
		app.ui.UpdateProgress("complete", "completed")
		app.ui.success("Workflow completed successfully!")
		
		// Cleanup worktree using git package
		app.ui.info("Cleaning up worktree...")
		app.gitOps.RemoveWorktree(worktreePath)
		
		return nil
	}

	app.ui.warning("Implementation validation failed")
	return fmt.Errorf("validation failed")
}

// Cleanup all worktrees using git package
func (app *CCWApp) cleanupAllWorktrees() error {
	worktrees, err := app.gitOps.ListWorktrees()
	if err != nil {
		return fmt.Errorf("failed to list worktrees: %w", err)
	}

	if len(worktrees) == 0 {
		app.ui.info("No worktrees to cleanup")
		return nil
	}

	app.ui.info(fmt.Sprintf("Found %d worktrees to cleanup", len(worktrees)))
	
	for _, worktreePath := range worktrees {
		app.ui.info(fmt.Sprintf("Removing worktree: %s", worktreePath))
		if err := app.gitOps.RemoveWorktree(worktreePath); err != nil {
			app.ui.warning(fmt.Sprintf("Failed to remove worktree %s: %v", worktreePath, err))
		} else {
			app.ui.success(fmt.Sprintf("Removed worktree: %s", worktreePath))
		}
	}

	return nil
}

// Cleanup application resources
func (app *CCWApp) cleanup() {
	if app.logger != nil {
		app.logger.Info("application", "CCW application shutting down", map[string]interface{}{
			"session_id": app.sessionID,
		})
		app.logger.Close()
	}
	
	if app.ui != nil {
		app.ui.restoreTerminalState()
	}
}

// Main function with updated package usage
func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(1)
	}

	// Handle command line arguments
	switch os.Args[1] {
	case "-h", "--help":
		usage()
		return
	case "--init-config":
		if len(os.Args) >= 3 {
			filename := os.Args[2]
			if err := config.GenerateSampleConfig(filename); err != nil {
				log.Fatalf("Failed to generate config file: %v", err)
			}
			fmt.Printf("Sample configuration file generated: %s\n", filename)
		} else {
			if err := config.GenerateSampleConfig("ccw.yaml"); err != nil {
				log.Fatalf("Failed to generate config file: %v", err)
			}
			fmt.Println("Sample configuration file generated: ccw.yaml")
		}
		return
	case "--cleanup":
		app, err := NewCCWApp()
		if err != nil {
			log.Fatalf("Failed to initialize application: %v", err)
		}
		defer app.cleanup()
		
		if err := app.cleanupAllWorktrees(); err != nil {
			log.Fatalf("Failed to cleanup worktrees: %v", err)
		}
		return
	case "--debug":
		if len(os.Args) < 3 {
			fmt.Println("Error: --debug requires an issue URL")
			usage()
			os.Exit(1)
		}
		os.Setenv("DEBUG_MODE", "true")
		issueURL := os.Args[2]
		
		app, err := NewCCWApp()
		if err != nil {
			log.Fatalf("Failed to initialize application: %v", err)
		}
		defer app.cleanup()
		
		if err := app.executeWorkflow(issueURL); err != nil {
			log.Fatalf("Workflow failed: %v", err)
		}
		return
	}

	// Default case: issue URL provided
	issueURL := os.Args[1]
	
	app, err := NewCCWApp()
	if err != nil {
		log.Fatalf("Failed to initialize application: %v", err)
	}
	defer app.cleanup()
	
	if err := app.executeWorkflow(issueURL); err != nil {
		log.Fatalf("Workflow failed: %v", err)
	}
}

// Helper functions
func parseTimeoutFromConfig(timeoutStr string) time.Duration {
	if duration, err := time.ParseDuration(timeoutStr); err == nil {
		return duration
	}
	return 30 * time.Second // default fallback
}

func generateBranchName(issueNumber int) string {
	timestamp := time.Now().Format("20060102-150405")
	return fmt.Sprintf("issue-%d-%s", issueNumber, timestamp)
}

func generateRandomID(length int) string {
	const charset = "abcdefghijklmnopqrstuvwxyz0123456789"
	result := make([]byte, length)
	for i := range result {
		result[i] = charset[time.Now().UnixNano()%int64(len(charset))]
	}
	return string(result)
}

func getEnvWithDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func parseIntWithDefault(value string, defaultValue int) (int, error) {
	if value == "" {
		return defaultValue, nil
	}
	if parsed, err := strconv.Atoi(value); err == nil {
		return parsed, nil
	}
	return defaultValue, fmt.Errorf("invalid integer: %s", value)
}

func usage() {
	fmt.Printf(`CCW - Claude Code Worktree Automation Tool

Usage: ccw <github-issue-url>

Arguments:
  github-issue-url    GitHub issue URL (e.g., https://github.com/owner/repo/issues/123)

Options:
  -h, --help         Show this help message
  --init-config      Generate sample configuration file (ccw.yaml)
  --init-config FILE Generate sample configuration file with custom name
  --cleanup          Clean up all worktrees
  --debug            Enable debug mode

This tool now uses a package-based architecture:
- config: YAML configuration management
- git: Git operations with timeout and retry logic
- ui: Terminal UI components
- More packages coming soon...

For configuration help: ccw --init-config
`)
}