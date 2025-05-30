package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"runtime"
	"runtime/debug"
	"strconv"
	"strings"
	"time"

	"ccw/claude"
	"ccw/commit"
	"ccw/config"
	"ccw/git"
	"ccw/github"
	"ccw/logging"
	"ccw/pr"
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
	commitGenerator   *commit.CommitMessageGenerator
	prManager         *pr.PRManager
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

	// Initialize commit generator
	commitGenerator := &commit.CommitMessageGenerator{}

	// Initialize PR manager
	prManager := pr.NewPRManager(timeout, ccwConfig.MaxRetries, ccwConfig.DebugMode)

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
		commitGenerator:   commitGenerator,
		prManager:         prManager,
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
	app.debugStep("executeWorkflow", "Starting workflow execution", map[string]interface{}{
		"issue_url": issueURL,
	})
	
	if app.ui.GetAnimations() {
		app.ui.DisplayProgressHeaderWithBackground()
	} else {
		app.ui.DisplayHeader()
	}

	// Step 1: Extract issue info
	app.debugStep("step1", "Extracting issue information", map[string]interface{}{
		"issue_url": issueURL,
	})
	
	app.ui.UpdateProgress("setup", "in_progress")
	owner, repo, issueNumber, err := github.ExtractIssueInfo(issueURL)
	if err != nil {
		app.logger.Error("workflow", "Failed to extract issue info", map[string]interface{}{
			"issue_url": issueURL,
			"error":     err.Error(),
		})
		return fmt.Errorf("failed to extract issue info: %w", err)
	}

	app.debugStep("step1", "Issue info extracted successfully", map[string]interface{}{
		"owner":        owner,
		"repo":         repo,
		"issue_number": issueNumber,
	})
	
	app.ui.Info(fmt.Sprintf("Processing issue #%d from %s/%s", issueNumber, owner, repo))

	// Step 2: Fetch issue data
	app.debugStep("step2", "Fetching GitHub issue data", map[string]interface{}{
		"owner":        owner,
		"repo":         repo,
		"issue_number": issueNumber,
	})
	
	app.ui.UpdateProgress("fetch", "in_progress")
	app.ui.Info("Fetching GitHub issue data...")
	
	issue, err := app.githubClient.GetIssue(owner, repo, issueNumber)
	if err != nil {
		app.ui.UpdateProgress("fetch", "failed")
		app.logger.Error("workflow", "Failed to fetch issue data", map[string]interface{}{
			"owner":        owner,
			"repo":         repo,
			"issue_number": issueNumber,
			"error":        err.Error(),
		})
		return fmt.Errorf("failed to fetch issue data: %w", err)
	}
	
	app.debugStep("step2", "Issue data fetched successfully", map[string]interface{}{
		"issue_title":  issue.Title,
		"issue_state":  issue.State,
		"issue_labels": len(issue.Labels),
		"issue_body":   truncateForLog(issue.Body, 200),
	})
	
	app.ui.UpdateProgress("fetch", "completed")

	// Step 3: Create worktree configuration using git package
	app.debugStep("step3", "Creating isolated development environment", map[string]interface{}{
		"issue_number": issueNumber,
	})
	
	app.ui.Info("Creating isolated development environment...")
	branchName := generateBranchName(issueNumber)
	worktreePath := filepath.Join(app.config.WorktreeBase, branchName)
	
	app.debugStep("step3", "Generated worktree configuration", map[string]interface{}{
		"branch_name":   branchName,
		"worktree_path": worktreePath,
		"base_path":     app.config.WorktreeBase,
	})
	
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
		app.logger.Error("workflow", "Failed to create worktree", map[string]interface{}{
			"branch_name":   branchName,
			"worktree_path": worktreePath,
			"error":         err.Error(),
		})
		return fmt.Errorf("failed to create worktree: %w", err)
	}
	
	app.debugStep("step3", "Worktree created successfully", map[string]interface{}{
		"branch_name":   branchName,
		"worktree_path": worktreePath,
	})
	
	app.ui.UpdateProgress("setup", "completed")

	// Save issue and worktree data
	app.debugStep("step4", "Saving issue and worktree data", map[string]interface{}{
		"worktree_path": worktreePath,
	})
	
	issueDataFile := filepath.Join(worktreePath, ".issue-data.json")
	issueData, _ := json.MarshalIndent(issue, "", "  ")
	if err := os.WriteFile(issueDataFile, issueData, 0644); err != nil {
		app.logger.Error("workflow", "Failed to save issue data", map[string]interface{}{
			"file":  issueDataFile,
			"error": err.Error(),
		})
	}

	worktreeDataFile := filepath.Join(worktreePath, ".worktree-config.json")
	worktreeData, _ := json.MarshalIndent(app.worktreeConfig, "", "  ")
	if err := os.WriteFile(worktreeDataFile, worktreeData, 0644); err != nil {
		app.logger.Error("workflow", "Failed to save worktree config", map[string]interface{}{
			"file":  worktreeDataFile,
			"error": err.Error(),
		})
	}

	// Implementation and validation steps...
	app.debugStep("step5", "Starting Claude Code implementation", map[string]interface{}{
		"worktree_path": worktreePath,
		"issue_number":  issueNumber,
	})
	
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
	
	app.debugStep("step5", "Executing Claude Code with context", map[string]interface{}{
		"claude_context": map[string]interface{}{
			"project_path": worktreePath,
			"task_type":    "implementation",
			"issue_title":  issue.Title,
		},
	})
	
	if err := app.claudeIntegration.RunWithContext(claudeCtx); err != nil {
		app.logger.Error("workflow", "Claude Code execution failed", map[string]interface{}{
			"error":         err.Error(),
			"worktree_path": worktreePath,
			"issue_number":  issueNumber,
		})
		app.ui.Warning(fmt.Sprintf("Claude Code execution warning: %v", err))
	} else {
		app.debugStep("step5", "Claude Code execution completed successfully", nil)
	}
	
	app.ui.UpdateProgress("implementation", "completed")

	// Validation using git package
	app.debugStep("step6", "Starting implementation validation", map[string]interface{}{
		"worktree_path": worktreePath,
	})
	
	app.ui.UpdateProgress("validation", "in_progress")
	app.ui.Info("Validating implementation...")
	
	validationResult, err := app.validator.ValidateImplementation(worktreePath)
	if err != nil {
		app.ui.UpdateProgress("validation", "failed")
		app.logger.Error("workflow", "Validation error", map[string]interface{}{
			"error":         err.Error(),
			"worktree_path": worktreePath,
		})
		return fmt.Errorf("validation error: %w", err)
	}

	app.debugStep("step6", "Validation completed", map[string]interface{}{
		"success":       validationResult.Success,
		"errors":        len(validationResult.Errors),
		"lint_success":  validationResult.LintResult != nil && validationResult.LintResult.Success,
		"build_success": validationResult.BuildResult != nil && validationResult.BuildResult.Success,
		"test_success":  validationResult.TestResult != nil && validationResult.TestResult.Success,
	})

	if validationResult.Success {
		app.ui.UpdateProgress("validation", "completed")
		app.ui.Success("Implementation validation successful!")
		
		// Convert git.ValidationResult to types.ValidationResult
		typesValidationResult := &types.ValidationResult{
			Success:     validationResult.Success,
			LintResult:  convertLintResult(validationResult.LintResult),
			BuildResult: convertBuildResult(validationResult.BuildResult),
			TestResult:  convertTestResult(validationResult.TestResult),
			Errors:      convertValidationErrors(validationResult.Errors),
			Duration:    validationResult.Duration,
			Timestamp:   validationResult.Timestamp,
		}
		
		// Execute async workflow for PR creation
		return app.executeAsyncPRWorkflow(issue, worktreePath, branchName, typesValidationResult)
	}

	app.ui.Warning("Implementation validation failed")
	app.logger.Error("workflow", "Implementation validation failed", map[string]interface{}{
		"validation_errors": validationResult.Errors,
		"worktree_path":     worktreePath,
	})
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
		enableDebugMode()
		issueURL := os.Args[2]
		
		app, err := NewCCWApp()
		if err != nil {
			log.Fatalf("Failed to initialize application: %v", err)
		}
		defer app.cleanup()
		
		if err := app.executeWorkflowWithRecovery(issueURL); err != nil {
			log.Fatalf("Workflow failed: %v", err)
		}
		return
	case "--verbose":
		enableVerboseMode()
		if len(os.Args) < 3 {
			fmt.Println("Error: --verbose requires an issue URL")
			usage()
			os.Exit(1)
		}
		issueURL := os.Args[2]
		
		app, err := NewCCWApp()
		if err != nil {
			log.Fatalf("Failed to initialize application: %v", err)
		}
		defer app.cleanup()
		
		if err := app.executeWorkflowWithRecovery(issueURL); err != nil {
			log.Fatalf("Workflow failed: %v", err)
		}
		return
	case "--trace":
		enableTraceMode()
		if len(os.Args) < 3 {
			fmt.Println("Error: --trace requires an issue URL")
			usage()
			os.Exit(1)
		}
		issueURL := os.Args[2]
		
		app, err := NewCCWApp()
		if err != nil {
			log.Fatalf("Failed to initialize application: %v", err)
		}
		defer app.cleanup()
		
		if err := app.executeWorkflowWithRecovery(issueURL); err != nil {
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
  --debug URL        Enable debug mode for specific issue
  --verbose          Enable verbose debug output for all operations
  --trace            Enable detailed stack traces and function call logging

Environment Variables:
  DEBUG_MODE=true    Enable debug output
  VERBOSE_MODE=true  Enable verbose logging
  TRACE_MODE=true    Enable stack trace logging
  CCW_LOG_FILE=true  Force enable file logging

Features:
- Interactive issue selection with arrow keys and spacebar
- Multi-issue processing support
- Configurable filtering by state and labels
- Comprehensive debugging and error reporting
- Package-based architecture for maintainability

For configuration help: ccw --init-config
`)
}

// Debug mode helpers
func enableDebugMode() {
	os.Setenv("DEBUG_MODE", "true")
	os.Setenv("CCW_LOG_FILE", "true")
	fmt.Println("[DEBUG] Debug mode enabled - detailed logging activated")
}

func enableVerboseMode() {
	os.Setenv("DEBUG_MODE", "true")
	os.Setenv("VERBOSE_MODE", "true")
	os.Setenv("CCW_LOG_FILE", "true")
	fmt.Println("[VERBOSE] Verbose mode enabled - comprehensive logging activated")
}

func enableTraceMode() {
	os.Setenv("DEBUG_MODE", "true")
	os.Setenv("VERBOSE_MODE", "true")
	os.Setenv("TRACE_MODE", "true")
	os.Setenv("CCW_LOG_FILE", "true")
	fmt.Println("[TRACE] Trace mode enabled - stack traces and function calls logged")
}

// Execute workflow with crash recovery and detailed error reporting
func (app *CCWApp) executeWorkflowWithRecovery(issueURL string) (err error) {
	// Set up panic recovery
	defer func() {
		if r := recover(); r != nil {
			stackTrace := string(debug.Stack())
			
			app.logger.Error("panic", "Application crashed with panic", map[string]interface{}{
				"panic_value": r,
				"stack_trace": stackTrace,
				"issue_url":   issueURL,
				"session_id":  app.sessionID,
				"go_version":  runtime.Version(),
				"goos":        runtime.GOOS,
				"goarch":      runtime.GOARCH,
			})
			
			app.ui.Error(fmt.Sprintf("CRASH DETECTED: %v", r))
			app.ui.Error("Stack trace logged to file. Please check the log for details.")
			
			// Save crash report
			app.saveCrashReport(r, stackTrace, issueURL)
			
			err = fmt.Errorf("application crashed: %v", r)
		}
	}()
	
	app.logger.Debug("workflow", "Starting workflow with recovery", map[string]interface{}{
		"issue_url":  issueURL,
		"session_id": app.sessionID,
		"debug_mode": app.config.DebugMode,
	})
	
	if os.Getenv("TRACE_MODE") == "true" {
		app.traceFunction("executeWorkflowWithRecovery", map[string]interface{}{
			"issue_url": issueURL,
		})
	}
	
	return app.executeWorkflow(issueURL)
}

// Save detailed crash report
func (app *CCWApp) saveCrashReport(panicValue interface{}, stackTrace, issueURL string) {
	crashReport := map[string]interface{}{
		"timestamp":   time.Now().Format(time.RFC3339),
		"session_id":  app.sessionID,
		"panic_value": panicValue,
		"stack_trace": stackTrace,
		"issue_url":   issueURL,
		"environment": map[string]interface{}{
			"go_version": runtime.Version(),
			"goos":       runtime.GOOS,
			"goarch":     runtime.GOARCH,
			"num_cpu":    runtime.NumCPU(),
			"debug_mode": app.config.DebugMode,
		},
		"command_line": os.Args,
		"working_dir":  func() string {
			if wd, err := os.Getwd(); err == nil {
				return wd
			}
			return "unknown"
		}(),
	}
	
	// Create crash reports directory
	crashDir := filepath.Join(".", ".ccw", "crashes")
	os.MkdirAll(crashDir, 0755)
	
	// Save crash report
	crashFile := filepath.Join(crashDir, fmt.Sprintf("crash-%s.json", app.sessionID))
	if data, err := json.MarshalIndent(crashReport, "", "  "); err == nil {
		os.WriteFile(crashFile, data, 0644)
		app.ui.Info(fmt.Sprintf("Crash report saved to: %s", crashFile))
	}
}

// Trace function calls in debug mode
func (app *CCWApp) traceFunction(funcName string, params map[string]interface{}) {
	if os.Getenv("TRACE_MODE") == "true" {
		app.logger.Debug("trace", fmt.Sprintf("FUNCTION: %s", funcName), params)
		
		// Get caller information
		if _, file, line, ok := runtime.Caller(1); ok {
			app.logger.Debug("trace", fmt.Sprintf("CALLER: %s:%d", filepath.Base(file), line), nil)
		}
	}
}

// Debug step helper function
func (app *CCWApp) debugStep(step, message string, context map[string]interface{}) {
	if os.Getenv("DEBUG_MODE") == "true" || os.Getenv("VERBOSE_MODE") == "true" {
		app.logger.Debug("workflow", fmt.Sprintf("[%s] %s", step, message), context)
	}
	
	if os.Getenv("TRACE_MODE") == "true" {
		app.traceFunction(fmt.Sprintf("debugStep:%s", step), context)
	}
}

// Truncate string for logging
func truncateForLog(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen] + "..."
}

// executeAsyncPRWorkflow handles the async PR creation workflow
func (app *CCWApp) executeAsyncPRWorkflow(issue *types.Issue, worktreePath, branchName string, validationResult *types.ValidationResult) error {
	app.debugStep("async_workflow", "Starting async PR creation workflow", map[string]interface{}{
		"worktree_path": worktreePath,
		"branch_name":   branchName,
	})

	// Step 1: Start async operations concurrently
	app.ui.Info("Starting async analysis and PR generation...")
	app.ui.UpdateProgress("analysis", "in_progress")

	// Start implementation summary generation (async)
	summaryResultChan := app.claudeIntegration.GenerateImplementationSummaryAsync(worktreePath)

	// Start commit message generation (async)
	issueForCommit := &commit.Issue{
		Number: issue.Number,
		Title:  issue.Title,
		Body:   issue.Body,
	}
	commitResultChan := app.commitGenerator.GenerateEnhancedCommitMessageAsync(worktreePath, issueForCommit)

	// Display progress while waiting for async operations
	app.ui.Info("⏳ Generating implementation summary...")
	app.ui.Info("⏳ Creating commit message...")

	// Wait for implementation summary
	var implementationSummary string
	select {
	case summaryResult := <-summaryResultChan:
		if summaryResult.Error != nil {
			app.ui.Warning(fmt.Sprintf("Implementation summary generation failed: %v", summaryResult.Error))
			implementationSummary = "Implementation completed with changes."
		} else {
			implementationSummary = summaryResult.Summary
			app.ui.Success("✅ Implementation summary generated")
		}
	case <-time.After(30 * time.Second):
		app.ui.Warning("⚠️ Implementation summary generation timed out")
		implementationSummary = "Implementation completed with changes."
	}

	// Wait for commit message
	var commitMessage string
	select {
	case commitResult := <-commitResultChan:
		if commitResult.Error != nil {
			app.ui.Warning(fmt.Sprintf("Commit message generation failed: %v", commitResult.Error))
			commitMessage = fmt.Sprintf("feat: %s\n\nResolves #%d", issue.Title, issue.Number)
		} else {
			commitMessage = commitResult.Message
			app.ui.Success("✅ Commit message generated")
		}
	case <-time.After(30 * time.Second):
		app.ui.Warning("⚠️ Commit message generation timed out")
		commitMessage = fmt.Sprintf("feat: %s\n\nResolves #%d", issue.Title, issue.Number)
	}
	
	// Use commit message for future commits (could be saved or used later)
	app.debugStep("commit_message", "Generated commit message", map[string]interface{}{
		"message": commitMessage,
	})

	app.ui.UpdateProgress("analysis", "completed")

	// Step 2: Push changes using git package
	app.debugStep("step7", "Pushing changes to remote", map[string]interface{}{
		"branch_name":   branchName,
		"worktree_path": worktreePath,
	})
	
	app.ui.Info("Pushing changes...")
	if err := app.gitOps.PushBranch(worktreePath, branchName); err != nil {
		app.logger.Error("workflow", "Failed to push branch", map[string]interface{}{
			"branch_name":   branchName,
			"worktree_path": worktreePath,
			"error":         err.Error(),
		})
		return fmt.Errorf("failed to push changes: %w", err)
	}
	
	app.debugStep("step7", "Branch pushed successfully", nil)

	// Step 3: Start PR description generation (async)
	app.ui.UpdateProgress("pr_creation", "in_progress")
	app.ui.Info("⏳ Generating PR description...")

	prDescRequest := &types.PRDescriptionRequest{
		Issue: issue,
		WorktreeConfig: &types.WorktreeConfig{
			BasePath:     app.worktreeConfig.BasePath,
			BranchName:   app.worktreeConfig.BranchName,
			WorktreePath: app.worktreeConfig.WorktreePath,
			IssueNumber:  app.worktreeConfig.IssueNumber,
			CreatedAt:    app.worktreeConfig.CreatedAt,
			Owner:        app.worktreeConfig.Owner,
			Repository:   app.worktreeConfig.Repository,
			IssueURL:     app.worktreeConfig.IssueURL,
		},
		ValidationResult:      validationResult,
		ImplementationSummary: implementationSummary,
	}

	prDescResultChan := app.claudeIntegration.GeneratePRDescriptionAsync(prDescRequest)

	// Wait for PR description with progress indicator
	var prDescription string
	select {
	case prDescResult := <-prDescResultChan:
		if prDescResult.Error != nil {
			app.ui.Warning(fmt.Sprintf("PR description generation failed: %v", prDescResult.Error))
			prDescription = app.claudeIntegration.CreateEnhancedPRDescription(prDescRequest)
		} else {
			prDescription = prDescResult.Description
			app.ui.Success("✅ PR description generated")
		}
	case <-time.After(2 * time.Minute): // Longer timeout for PR description
		app.ui.Warning("⚠️ PR description generation timed out, using fallback")
		prDescription = app.claudeIntegration.CreateEnhancedPRDescription(prDescRequest)
	}

	// Step 4: Create PR (async)
	app.ui.Info("⏳ Creating pull request...")
	prRequest := &types.PRRequest{
		Title: fmt.Sprintf("Resolve #%d: %s", issue.Number, issue.Title),
		Body:  prDescription,
		Head:  branchName,
		Base:  "master", // or "main"
		MaintainerCanModify: true,
	}

	prResultChan := app.prManager.CreatePullRequestAsync(prRequest, worktreePath)

	// Wait for PR creation
	select {
	case prResult := <-prResultChan:
		if prResult.Error != nil {
			app.ui.UpdateProgress("pr_creation", "failed")
			return fmt.Errorf("failed to create PR: %w", prResult.Error)
		}
		
		app.ui.UpdateProgress("pr_creation", "completed")
		app.ui.Success(fmt.Sprintf("✅ Pull request created: %s", prResult.PullRequest.HTMLURL))
		
		// Step 5: Monitor CI checks (async, optional)
		app.ui.Info("⏳ Monitoring CI checks...")
		ciResultChan := app.prManager.MonitorPRChecksAsync(prResult.PullRequest.HTMLURL, 5*time.Minute)
		
		select {
		case ciResult := <-ciResultChan:
			if ciResult.Error != nil {
				app.ui.Warning(fmt.Sprintf("CI monitoring failed: %v", ciResult.Error))
			} else {
				app.ui.Info(fmt.Sprintf("CI Status: %s", ciResult.Status.Status))
			}
		case <-time.After(1 * time.Minute): // Short timeout for CI monitoring demo
			app.ui.Info("CI monitoring will continue in background")
		}
		
	case <-time.After(1 * time.Minute):
		app.ui.UpdateProgress("pr_creation", "failed")
		return fmt.Errorf("PR creation timed out")
	}

	app.ui.UpdateProgress("complete", "completed")
	app.ui.Success("🎉 Async workflow completed successfully!")
	
	// Cleanup worktree using git package
	app.debugStep("step8", "Cleaning up worktree", map[string]interface{}{
		"worktree_path": worktreePath,
	})
	
	app.ui.Info("Cleaning up worktree...")
	if err := app.gitOps.RemoveWorktree(worktreePath); err != nil {
		app.logger.Error("workflow", "Failed to cleanup worktree", map[string]interface{}{
			"worktree_path": worktreePath,
			"error":         err.Error(),
		})
	} else {
		app.debugStep("step8", "Worktree cleaned up successfully", nil)
	}
	
	return nil
}

// Converter functions to map between git and types packages

func convertLintResult(gitResult *git.LintResult) *types.LintResult {
	if gitResult == nil {
		return nil
	}
	return &types.LintResult{
		Success:   gitResult.Success,
		Output:    gitResult.Output,
		Errors:    gitResult.Errors,
		Warnings:  gitResult.Warnings,
		AutoFixed: gitResult.AutoFixed,
	}
}

func convertBuildResult(gitResult *git.BuildResult) *types.BuildResult {
	if gitResult == nil {
		return nil
	}
	return &types.BuildResult{
		Success: gitResult.Success,
		Output:  gitResult.Output,
		Error:   gitResult.Error,
	}
}

func convertTestResult(gitResult *git.TestResult) *types.TestResult {
	if gitResult == nil {
		return nil
	}
	return &types.TestResult{
		Success:   gitResult.Success,
		Output:    gitResult.Output,
		TestCount: gitResult.TestCount,
		Passed:    gitResult.Passed,
		Failed:    gitResult.Failed,
	}
}

func convertValidationErrors(gitErrors []git.ValidationError) []types.ValidationError {
	if gitErrors == nil {
		return nil
	}
	
	typesErrors := make([]types.ValidationError, len(gitErrors))
	for i, gitError := range gitErrors {
		typesErrors[i] = types.ValidationError{
			Type:        gitError.Type,
			Message:     gitError.Message,
			File:        gitError.File,
			Line:        gitError.Line,
			Recoverable: gitError.Recoverable,
		}
	}
	return typesErrors
}