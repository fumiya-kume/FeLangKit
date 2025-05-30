package app

import (
	"fmt"
	"log"
	"os"
	"runtime"
	"runtime/debug"
	"strconv"
	"strings"
	"time"

	"ccw/github"
)

// HandleListCommand processes the list command with argument parsing
func HandleListCommand() {
	var repoURL string
	var startArgIndex int

	// Check if repository URL is provided or use current repository
	if len(os.Args) < 3 {
		// No arguments provided, use current repository
		currentRepo, err := github.GetCurrentRepoURL()
		if err != nil {
			fmt.Printf("Error: Failed to detect current repository: %v\n", err)
			printListUsage()
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
				printListUsage()
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
	defer app.Cleanup()

	if err := app.ExecuteListWorkflow(repoURL, state, labels, limit); err != nil {
		log.Fatalf("List workflow failed: %v", err)
	}
}

// ExecuteWorkflowWithRecovery executes workflow with crash recovery and detailed error reporting
func (app *CCWApp) ExecuteWorkflowWithRecovery(issueURL string) (err error) {
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
	
	return app.ExecuteWorkflow(issueURL)
}

// CleanupAllWorktrees removes all existing worktrees
func (app *CCWApp) CleanupAllWorktrees() error {
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

// Debug mode helpers
func EnableDebugMode() {
	os.Setenv("DEBUG_MODE", "true")
	os.Setenv("CCW_LOG_FILE", "true")
	fmt.Println("[DEBUG] Debug mode enabled - detailed logging activated")
}

func EnableVerboseMode() {
	os.Setenv("DEBUG_MODE", "true")
	os.Setenv("VERBOSE_MODE", "true")
	os.Setenv("CCW_LOG_FILE", "true")
	fmt.Println("[VERBOSE] Verbose mode enabled - comprehensive logging activated")
}

func EnableTraceMode() {
	os.Setenv("DEBUG_MODE", "true")
	os.Setenv("VERBOSE_MODE", "true")
	os.Setenv("TRACE_MODE", "true")
	os.Setenv("CCW_LOG_FILE", "true")
	fmt.Println("[TRACE] Trace mode enabled - stack traces and function calls logged")
}

// PrintUsage displays the main usage information
func PrintUsage() {
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

// printListUsage displays usage for the list command
func printListUsage() {
	fmt.Println("Usage: ccw list [repo-url] [options]")
	fmt.Println("  repo-url      Repository URL (e.g., https://github.com/owner/repo or owner/repo)")
	fmt.Println("                If not provided, uses current repository's GitHub remote")
	fmt.Println("  --state       Issue state: open, closed, all (default: open)")
	fmt.Println("  --labels      Comma-separated list of labels to filter by")
	fmt.Println("  --limit       Maximum number of issues to fetch (default: 20)")
}

// saveCrashReport saves detailed crash information
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
	
	// Log crash report using logger
	if app.logger != nil {
		app.logger.Error("crash_report", fmt.Sprintf("Application crash: %v", panicValue), crashReport)
	}
}