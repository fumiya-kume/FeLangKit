package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"strings"
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

	uiManager := ui.NewUIManager(ccwConfig.UI.Theme, ccwConfig.UI.Animations, ccwConfig.DebugMode)

	// Initialize logger
	enableFileLogging := ccwConfig.DebugMode || getEnvWithDefault("CCW_LOG_FILE", "false") == "true"
	logger, err := logging.NewLogger(sessionID, enableFileLogging)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize logger: %w", err)
	}

	// Initialize error store
	errorStore := logging.NewErrorStore(filepath.Join(".", ".ccw", "errors.json"), 1000)

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

// Execute interactive issue selection workflow
func (app *CCWApp) executeListWorkflow(repoURL string, state string, labels []string, limit int) error {
	// Extract repository information
	owner, repo, err := github.ExtractRepoInfo(repoURL)
	if err != nil {
		return fmt.Errorf("failed to extract repository info: %w", err)
	}

	app.ui.Info(fmt.Sprintf("Fetching issues from %s/%s...", owner, repo))
	
	// Fetch issues from GitHub
	issues, err := app.githubClient.ListIssues(owner, repo, state, labels, limit)
	if err != nil {
		return fmt.Errorf("failed to fetch issues: %w", err)
	}

	if len(issues) == 0 {
		app.ui.Warning("No issues found matching the criteria")
		return nil
	}

	// Display issue selection interface
	selectedIssues, err := app.ui.DisplayIssueSelection(issues)
	if err != nil {
		return fmt.Errorf("issue selection failed: %w", err)
	}

	app.ui.Info(fmt.Sprintf("Selected %d issue(s) for processing", len(selectedIssues)))

	// Process each selected issue
	for i, issue := range selectedIssues {
		app.ui.Info(fmt.Sprintf("Processing issue %d of %d: #%d %s", i+1, len(selectedIssues), issue.Number, issue.Title))
		
		// Construct issue URL
		issueURL := fmt.Sprintf("https://github.com/%s/%s/issues/%d", owner, repo, issue.Number)
		
		// Execute normal workflow for this issue
		if err := app.executeWorkflow(issueURL); err != nil {
			app.ui.Warning(fmt.Sprintf("Failed to process issue #%d: %v", issue.Number, err))
			// Continue with next issue rather than failing completely
			continue
		}
		
		app.ui.Success(fmt.Sprintf("Successfully processed issue #%d", issue.Number))
	}

	app.ui.Success("All selected issues have been processed!")
	return nil
}

// Updated workflow execution using new packages
func (app *CCWApp) executeWorkflow(issueURL string) error {
	if app.ui.GetAnimations() {
		app.ui.DisplayProgressHeaderWithBackground()
	} else {
		app.ui.DisplayHeader()
	}

	// Step 1: Extract issue info
	app.ui.UpdateProgress("setup", "in_progress")
	owner, repo, issueNumber, err := github.ExtractIssueInfo(issueURL)
	if err != nil {
		return fmt.Errorf("failed to extract issue info: %w", err)
	}

	app.ui.Info(fmt.Sprintf("Processing issue #%d from %s/%s", issueNumber, owner, repo))

	// Step 2: Fetch issue data
	app.ui.UpdateProgress("fetch", "in_progress")
	app.ui.Info("Fetching GitHub issue data...")
	
	issue, err := app.githubClient.GetIssue(owner, repo, issueNumber)
	if err != nil {
		app.ui.UpdateProgress("fetch", "failed")
		return fmt.Errorf("failed to fetch issue data: %w", err)
	}
	app.ui.UpdateProgress("fetch", "completed")

	// Step 3: Create worktree configuration using git package
	app.ui.Info("Creating isolated development environment...")
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
	app.ui.Info("Running implementation...")
	
	// Run Claude Code (simplified for demo)
	// Convert git.WorktreeConfig to types.WorktreeConfig
	typesWorktreeConfig := &types.WorktreeConfig{
		BasePath:     app.worktreeConfig.BasePath,
		BranchName:   app.worktreeConfig.BranchName,
		WorktreePath: app.worktreeConfig.WorktreePath,
		IssueNumber:  app.worktreeConfig.IssueNumber,
		CreatedAt:    app.worktreeConfig.CreatedAt,
		Owner:        app.worktreeConfig.Owner,
		Repository:   app.worktreeConfig.Repository,
		IssueURL:     app.worktreeConfig.IssueURL,
	}
	
	claudeCtx := &types.ClaudeContext{
		IssueData:      issue,
		WorktreeConfig: typesWorktreeConfig,
		ProjectPath:    worktreePath,
		TaskType:       "implementation",
	}
	
	if err := app.claudeIntegration.RunWithContext(claudeCtx); err != nil {
		app.ui.Warning(fmt.Sprintf("Claude Code execution warning: %v", err))
	}
	app.ui.UpdateProgress("implementation", "completed")

	// Validation using git package
	app.ui.UpdateProgress("validation", "in_progress")
	app.ui.Info("Validating implementation...")
	
	validationResult, err := app.validator.ValidateImplementation(worktreePath)
	if err != nil {
		app.ui.UpdateProgress("validation", "failed")
		return fmt.Errorf("validation error: %w", err)
	}

	if validationResult.Success {
		app.ui.UpdateProgress("validation", "completed")
		app.ui.Success("Implementation validation successful!")
		
		// Push changes using git package
		app.ui.Info("Pushing changes...")
		if err := app.gitOps.PushBranch(worktreePath, branchName); err != nil {
			return fmt.Errorf("failed to push changes: %w", err)
		}
		
		app.ui.UpdateProgress("complete", "completed")
		app.ui.Success("Workflow completed successfully!")
		
		// Cleanup worktree using git package
		app.ui.Info("Cleaning up worktree...")
		app.gitOps.RemoveWorktree(worktreePath)
		
		return nil
	}

	app.ui.Warning("Implementation validation failed")
	return fmt.Errorf("validation failed")
}

// Cleanup all worktrees using git package
func (app *CCWApp) cleanupAllWorktrees() error {
	worktrees, err := app.gitOps.ListWorktrees()
	if err != nil {
		return fmt.Errorf("failed to list worktrees: %w", err)
	}

	if len(worktrees) == 0 {
		app.ui.Info("No worktrees to cleanup")
		return nil
	}

	app.ui.Info(fmt.Sprintf("Found %d worktrees to cleanup", len(worktrees)))
	
	for _, worktreePath := range worktrees {
		app.ui.Info(fmt.Sprintf("Removing worktree: %s", worktreePath))
		if err := app.gitOps.RemoveWorktree(worktreePath); err != nil {
			app.ui.Warning(fmt.Sprintf("Failed to remove worktree %s: %v", worktreePath, err))
		} else {
			app.ui.Success(fmt.Sprintf("Removed worktree: %s", worktreePath))
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
		app.ui.RestoreTerminalState()
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
	case "list":
		handleListCommand()
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

// Handle the list command with argument parsing
func handleListCommand() {
	var repoURL string
	var startArgIndex int

	// Check if repository URL is provided or use current repository
	if len(os.Args) < 3 {
		// No arguments provided, use current repository
		currentRepo, err := github.GetCurrentRepoURL()
		if err != nil {
			fmt.Printf("Error: Failed to detect current repository: %v\n", err)
			fmt.Println("Usage: ccw list [repo-url] [options]")
			fmt.Println("  repo-url      Repository URL (e.g., https://github.com/owner/repo or owner/repo)")
			fmt.Println("                If not provided, uses current repository's GitHub remote")
			fmt.Println("  --state       Issue state: open, closed, all (default: open)")
			fmt.Println("  --labels      Comma-separated list of labels to filter by")
			fmt.Println("  --limit       Maximum number of issues to fetch (default: 20)")
			os.Exit(1)
		}
		repoURL = currentRepo
		startArgIndex = 2 // Start parsing options from index 2
	} else {
		// Check if the first argument is an option or repository URL
		firstArg := os.Args[2]
		if strings.HasPrefix(firstArg, "--") {
			// First argument is an option, use current repository
			currentRepo, err := github.GetCurrentRepoURL()
			if err != nil {
				fmt.Printf("Error: Failed to detect current repository: %v\n", err)
				fmt.Println("Usage: ccw list [repo-url] [options]")
				fmt.Println("  repo-url      Repository URL (e.g., https://github.com/owner/repo or owner/repo)")
				fmt.Println("                If not provided, uses current repository's GitHub remote")
				os.Exit(1)
			}
			repoURL = currentRepo
			startArgIndex = 2 // Start parsing options from index 2
		} else {
			// First argument is repository URL
			repoURL = firstArg
			startArgIndex = 3 // Start parsing options from index 3
		}
	}

	state := "open"      // default state
	labels := []string{} // default no label filter
	limit := 20          // default limit

	// Parse additional arguments
	for i := startArgIndex; i < len(os.Args); i++ {
		switch os.Args[i] {
		case "--state":
			if i+1 < len(os.Args) {
				state = os.Args[i+1]
				i++ // skip next argument
			} else {
				fmt.Println("Error: --state requires a value")
				os.Exit(1)
			}
		case "--labels":
			if i+1 < len(os.Args) {
				labelStr := os.Args[i+1]
				labels = strings.Split(labelStr, ",")
				// Trim whitespace from labels
				for j := range labels {
					labels[j] = strings.TrimSpace(labels[j])
				}
				i++ // skip next argument
			} else {
				fmt.Println("Error: --labels requires a value")
				os.Exit(1)
			}
		case "--limit":
			if i+1 < len(os.Args) {
				var err error
				limit, err = strconv.Atoi(os.Args[i+1])
				if err != nil {
					fmt.Printf("Error: --limit requires a valid number, got: %s\n", os.Args[i+1])
					os.Exit(1)
				}
				if limit <= 0 {
					fmt.Println("Error: --limit must be greater than 0")
					os.Exit(1)
				}
				i++ // skip next argument
			} else {
				fmt.Println("Error: --limit requires a value")
				os.Exit(1)
			}
		default:
			fmt.Printf("Error: unknown option %s\n", os.Args[i])
			os.Exit(1)
		}
	}

	// Validate state
	if state != "open" && state != "closed" && state != "all" {
		fmt.Printf("Error: invalid state '%s'. Must be: open, closed, or all\n", state)
		os.Exit(1)
	}

	// Initialize app and execute list workflow
	app, err := NewCCWApp()
	if err != nil {
		log.Fatalf("Failed to initialize application: %v", err)
	}
	defer app.cleanup()

	if err := app.executeListWorkflow(repoURL, state, labels, limit); err != nil {
		log.Fatalf("List workflow failed: %v", err)
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

Usage: 
  ccw <github-issue-url>                  Process a specific GitHub issue
  ccw list [repo-url] [options]           List and select issues interactively

Arguments:
  github-issue-url    GitHub issue URL (e.g., https://github.com/owner/repo/issues/123)
  repo-url           Repository URL (e.g., https://github.com/owner/repo or owner/repo)
                     If not provided, uses current repository's GitHub remote

List Command Options:
  --state            Issue state: open, closed, all (default: open)
  --labels           Comma-separated list of labels to filter by
  --limit            Maximum number of issues to fetch (default: 20)

Examples:
  ccw https://github.com/owner/repo/issues/123
  ccw list                                           # Use current repository
  ccw list owner/repo                                # Use specific repository
  ccw list --state open --limit 10                  # Use current repository with options
  ccw list https://github.com/owner/repo --state open --limit 10
  ccw list owner/repo --labels bug,enhancement --state all

General Options:
  -h, --help         Show this help message
  --init-config      Generate sample configuration file (ccw.yaml)
  --init-config FILE Generate sample configuration file with custom name
  --cleanup          Clean up all worktrees
  --debug            Enable debug mode

Features:
- Interactive issue selection with arrow keys and spacebar
- Multi-issue processing support
- Configurable filtering by state and labels
- Package-based architecture for maintainability

For configuration help: ccw --init-config
`)
}