package app

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"runtime"
	"runtime/debug"
	"strconv"
	"strings"
	"time"

	"ccw/config"
	"ccw/github"
	"ccw/ui"
)

// getConsoleCharCmd returns console-safe characters based on CI environment
func getConsoleCharCmd(fancy, simple string) string {
	if os.Getenv("CCW_CONSOLE_MODE") == "true" || 
	   os.Getenv("CI") == "true" || 
	   os.Getenv("GITHUB_ACTIONS") == "true" ||
	   os.Getenv("GITLAB_CI") == "true" ||
	   os.Getenv("JENKINS_URL") != "" {
		return simple
	}
	return fancy
}

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

// HandleDoctorCommand performs system diagnostic checks
func HandleDoctorCommand() {
	// Check if we should use Bubble Tea UI
	if shouldUseBubbleTeaForDoctor() {
		// Use beautiful interactive Bubble Tea UI
		if err := ui.RunDoctorUI(); err != nil {
			fmt.Printf("Error running interactive doctor UI: %v\n", err)
			fmt.Println("Falling back to console mode...")
			runConsoleDoctorCommand()
		}
		return
	}

	// Fall back to console mode
	runConsoleDoctorCommand()
}

// shouldUseBubbleTeaForDoctor determines if Bubble Tea UI should be used for doctor command
func shouldUseBubbleTeaForDoctor() bool {
	// Check if console mode is forced
	if os.Getenv("CCW_CONSOLE_MODE") == "true" {
		return false
	}

	// Create a temporary UI manager to test capabilities
	testUI := ui.NewUIManagerWithDefaults()
	return testUI.ShouldUseBubbleTea()
}

// runConsoleDoctorCommand runs the original console-based doctor command
func runConsoleDoctorCommand() {
	title := getConsoleCharCmd("🩺 CCW Doctor - System Diagnostic", "CCW Doctor - System Diagnostic")
	fmt.Println(title)
	fmt.Println("==================================")
	fmt.Println()

	allGood := true

	// Load current configuration to display settings
	ccwConfig, configErr := config.LoadConfiguration()

	checkIcon := getConsoleCharCmd("✓", "[CHECK]")
	
	// Check Go version
	fmt.Printf("%s Checking Go version... ", checkIcon)
	goVersion := runtime.Version()
	fmt.Printf("%s\n", goVersion)

	// Check Git availability
	fmt.Printf("%s Checking Git availability... ", checkIcon)
	if checkCommandAvailable("git") {
		if gitVersion := getCommandVersion("git", "--version"); gitVersion != "" {
			fmt.Printf("%s\n", gitVersion)
		} else {
			fmt.Println("available")
		}
	} else {
		errorIcon := getConsoleCharCmd("❌", "[ERROR]")
		fmt.Printf("%s NOT FOUND\n", errorIcon)
		allGood = false
	}

	// Check GitHub CLI availability
	fmt.Printf("%s Checking GitHub CLI (gh)... ", checkIcon)
	if checkCommandAvailable("gh") {
		if ghVersion := getCommandVersion("gh", "--version"); ghVersion != "" {
			fmt.Printf("%s\n", strings.Split(ghVersion, "\n")[0])
		} else {
			fmt.Println("available")
		}
	} else {
		errorIcon := getConsoleCharCmd("❌", "[ERROR]")
		fmt.Printf("%s NOT FOUND\n", errorIcon)
		allGood = false
	}

	// Check Claude Code availability
	fmt.Printf("%s Checking Claude Code CLI... ", checkIcon)
	if checkCommandAvailable("claude") {
		fmt.Println("available")
	} else {
		warningIcon := getConsoleCharCmd("⚠️", "[WARNING]")
		fmt.Printf("%s NOT FOUND (optional)\n", warningIcon)
	}

	// Check SwiftLint availability (for Swift projects)
	fmt.Printf("%s Checking SwiftLint... ", checkIcon)
	if checkCommandAvailable("swiftlint") {
		if swiftlintVersion := getCommandVersion("swiftlint", "--version"); swiftlintVersion != "" {
			fmt.Printf("%s\n", swiftlintVersion)
		} else {
			fmt.Println("available")
		}
	} else {
		warningIcon := getConsoleCharCmd("⚠️", "[WARNING]")
		fmt.Printf("%s NOT FOUND (optional for Swift projects)\n", warningIcon)
	}

	// Check current directory is a Git repository
	fmt.Printf("%s Checking Git repository... ", checkIcon)
	if isGitRepository() {
		if repoURL, err := github.GetCurrentRepoURL(); err == nil {
			fmt.Printf("valid (%s)\n", repoURL)
		} else {
			fmt.Println("valid (local)")
		}
	} else {
		errorIcon := getConsoleCharCmd("❌", "[ERROR]")
		fmt.Printf("%s Current directory is not a Git repository\n", errorIcon)
		allGood = false
	}

	// Check environment variables
	fmt.Printf("%s Checking environment... ", checkIcon)
	envIssues := []string{}
	
	if os.Getenv("GITHUB_TOKEN") == "" && os.Getenv("GH_TOKEN") == "" {
		envIssues = append(envIssues, "no GitHub token (GH_TOKEN or GITHUB_TOKEN)")
	}
	
	if len(envIssues) > 0 {
		warningIcon := getConsoleCharCmd("⚠️", "[WARNING]")
		fmt.Printf("%s %s\n", warningIcon, strings.Join(envIssues, ", "))
	} else {
		fmt.Println("good")
	}

	// Check CCW configuration
	fmt.Printf("%s Checking CCW configuration... ", checkIcon)
	if _, err := os.Stat("ccw.yaml"); err == nil {
		fmt.Println("ccw.yaml found")
	} else if _, err := os.Stat("ccw.json"); err == nil {
		fmt.Println("ccw.json found")
	} else {
		warningIcon := getConsoleCharCmd("⚠️", "[WARNING]")
		fmt.Printf("%s no config file (will use defaults)\n", warningIcon)
	}

	// UI Configuration Section
	fmt.Println()
	uiConfigTitle := getConsoleCharCmd("🎨 UI Configuration:", "UI Configuration:")
	fmt.Println(uiConfigTitle)
	if configErr != nil {
		warningIcon := getConsoleCharCmd("⚠️", "[WARNING]")
		fmt.Printf("   %s Could not load configuration, showing detected values\n", warningIcon)
	}
	
	// Console mode detection
	fmt.Print("   Console Mode: ")
	if os.Getenv("CCW_CONSOLE_MODE") == "true" {
		fmt.Println("enabled (forced via CCW_CONSOLE_MODE)")
	} else {
		// Create a temporary UI manager to test Bubble Tea support
		testUI := ui.NewUIManagerWithDefaults()
		if testUI.ShouldUseBubbleTea() {
			fmt.Println("disabled (Bubble Tea UI available)")
		} else {
			fmt.Println("enabled (Bubble Tea UI not available)")
		}
	}
	
	// Theme configuration
	fmt.Print("   Theme: ")
	if ccwConfig != nil {
		fmt.Printf("%s", ccwConfig.UI.Theme)
		if envTheme := os.Getenv("CCW_THEME"); envTheme != "" {
			fmt.Printf(" (overridden by CCW_THEME=%s)", envTheme)
		}
		fmt.Println()
	} else {
		if envTheme := os.Getenv("CCW_THEME"); envTheme != "" {
			fmt.Printf("%s (from CCW_THEME)\n", envTheme)
		} else {
			fmt.Println("auto-detected")
		}
	}
	
	// Color support
	fmt.Print("   Color Support: ")
	if ccwConfig != nil && !ccwConfig.UI.ColorOutput {
		fmt.Println("disabled (config)")
	} else if os.Getenv("CCW_COLOR_OUTPUT") == "false" {
		fmt.Println("disabled (CCW_COLOR_OUTPUT=false)")
	} else if os.Getenv("NO_COLOR") != "" {
		fmt.Println("disabled (NO_COLOR set)")
	} else {
		fmt.Println("enabled")
	}
	
	// Animations
	fmt.Print("   Animations: ")
	if ccwConfig != nil {
		if ccwConfig.UI.Animations {
			fmt.Print("enabled")
		} else {
			fmt.Print("disabled")
		}
		if envAnim := os.Getenv("CCW_ANIMATIONS"); envAnim != "" {
			fmt.Printf(" (overridden by CCW_ANIMATIONS=%s)", envAnim)
		}
		fmt.Println()
	} else {
		if envAnim := os.Getenv("CCW_ANIMATIONS"); envAnim != "" {
			fmt.Printf("%s (from CCW_ANIMATIONS)\n", envAnim)
		} else {
			fmt.Println("enabled (default)")
		}
	}
	
	// Unicode support
	fmt.Print("   Unicode Support: ")
	if ccwConfig != nil {
		if ccwConfig.UI.Unicode {
			fmt.Print("enabled")
		} else {
			fmt.Print("disabled")
		}
		if envUnicode := os.Getenv("CCW_UNICODE"); envUnicode != "" {
			fmt.Printf(" (overridden by CCW_UNICODE=%s)", envUnicode)
		}
		fmt.Println()
	} else {
		if envUnicode := os.Getenv("CCW_UNICODE"); envUnicode != "" {
			fmt.Printf("%s (from CCW_UNICODE)\n", envUnicode)
		} else {
			fmt.Println("enabled (default)")
		}
	}

	// Display terminal capabilities
	fmt.Print("   Terminal Width/Height: ")
	if ccwConfig != nil && ccwConfig.UI.Width > 0 && ccwConfig.UI.Height > 0 {
		fmt.Printf("%dx%d (config)\n", ccwConfig.UI.Width, ccwConfig.UI.Height)
	} else {
		fmt.Println("auto-detected")
	}

	// System information
	fmt.Println()
	systemInfoTitle := getConsoleCharCmd("📊 System Information:", "System Information:")
	fmt.Println(systemInfoTitle)
	fmt.Printf("   OS: %s %s\n", runtime.GOOS, runtime.GOARCH)
	fmt.Printf("   CPUs: %d\n", runtime.NumCPU())
	
	if wd, err := os.Getwd(); err == nil {
		fmt.Printf("   Working Directory: %s\n", wd)
	}

	// Configuration summary
	if ccwConfig != nil {
		fmt.Println()
		configTitle := getConsoleCharCmd("⚙️ Current Configuration:", "Current Configuration:")
		fmt.Println(configTitle)
		fmt.Printf("   Debug Mode: %v\n", ccwConfig.DebugMode)
		fmt.Printf("   Worktree Base: %s\n", ccwConfig.WorktreeBase)
		fmt.Printf("   Max Retries: %d\n", ccwConfig.MaxRetries)
		fmt.Printf("   Claude Timeout: %s\n", ccwConfig.ClaudeTimeout)
		
		if ccwConfig.Git.Timeout != "" {
			fmt.Printf("   Git Timeout: %s\n", ccwConfig.Git.Timeout)
		}
		if ccwConfig.Git.DefaultBranch != "" {
			fmt.Printf("   Default Branch: %s\n", ccwConfig.Git.DefaultBranch)
		}
		
		// Performance settings
		if ccwConfig.Performance.Level > 0 {
			fmt.Printf("   Performance Level: %d\n", ccwConfig.Performance.Level)
			fmt.Printf("   Adaptive Refresh: %v\n", ccwConfig.Performance.AdaptiveRefresh)
			fmt.Printf("   Content Caching: %v\n", ccwConfig.Performance.ContentCaching)
		}
	}

	// Summary
	fmt.Println()
	if allGood {
		successIcon := getConsoleCharCmd("🎉", "[SUCCESS]")
		fmt.Printf("%s All critical dependencies are available!\n", successIcon)
		fmt.Println("   CCW should work correctly in this environment.")
	} else {
		errorIcon := getConsoleCharCmd("❌", "[ERROR]")
		fmt.Printf("%s Some critical dependencies are missing.\n", errorIcon)
		fmt.Println("   Please install missing tools before using CCW.")
	}
	
	fmt.Println()
	tipsIcon := getConsoleCharCmd("💡", "[TIPS]")
	fmt.Printf("%s Tips:\n", tipsIcon)
	fmt.Println("   - Install GitHub CLI: brew install gh")
	fmt.Println("   - Install Claude Code: https://claude.ai/code")
	fmt.Println("   - Install SwiftLint: brew install swiftlint")
	fmt.Println("   - Set GitHub token: export GH_TOKEN=your_token")
	fmt.Println("   - Force console mode: export CCW_CONSOLE_MODE=true")
	fmt.Println("   - Set theme: export CCW_THEME=dark|light|high-contrast")
	fmt.Println("   - Generate config: ccw --init-config")
}

// checkCommandAvailable checks if a command is available in PATH
func checkCommandAvailable(command string) bool {
	_, err := exec.LookPath(command)
	return err == nil
}

// getCommandVersion gets the version string from a command
func getCommandVersion(command string, versionFlag string) string {
	cmd := exec.Command(command, versionFlag)
	output, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(output))
}

// isGitRepository checks if the current directory is a Git repository
func isGitRepository() bool {
	cmd := exec.Command("git", "rev-parse", "--git-dir")
	err := cmd.Run()
	return err == nil
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
  ccw doctor                              Run system diagnostic checks

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