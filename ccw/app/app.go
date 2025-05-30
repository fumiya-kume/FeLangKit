package app

import (
	"fmt"
	"os"
	"path/filepath"
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

// CCWApp represents the main application structure
type CCWApp struct {
	config            *config.Config
	gitOps            *git.Operations
	validator         *git.QualityValidator
	worktreeConfig    *git.WorktreeConfig
	sessionID         string
	
	// Component integrations
	githubClient      *github.GitHubClient
	claudeIntegration *claude.ClaudeIntegration
	commitGenerator   *commit.CommitMessageGenerator
	prManager         *pr.PRManager
	ui                *ui.UIManager
	logger            *logging.Logger
	errorStore        *types.ErrorStore
}

// NewCCWApp initializes a new CCW application instance
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

// Cleanup application resources
func (app *CCWApp) Cleanup() {
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

// Helper functions

func parseTimeoutFromConfig(timeoutStr string) time.Duration {
	if duration, err := time.ParseDuration(timeoutStr); err == nil {
		return duration
	}
	return 30 * time.Second // default fallback
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