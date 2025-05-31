package ui

import (
	"fmt"
	"time"

	"ccw/types"
)

// InitializeProgress initializes the progress tracker with workflow steps
func (ui *UIManager) InitializeProgress() {
	ui.progressTracker = &types.ProgressTracker{
		Steps: []types.WorkflowStep{
			{ID: "setup", Name: "Setting up worktree", Description: "Creating isolated development environment", Status: "pending"},
			{ID: "fetch", Name: "Fetching issue data", Description: "Retrieving GitHub issue information", Status: "pending"},
			{ID: "analysis", Name: "Generating analysis", Description: "Preparing implementation context", Status: "pending"},
			{ID: "implementation", Name: "Running Claude Code", Description: "Automated implementation process", Status: "pending"},
			{ID: "validation", Name: "Validating implementation", Description: "Running quality checks", Status: "pending"},
			{ID: "commit", Name: "Committing changes", Description: "Creating git commit with all changes", Status: "pending"},
			{ID: "pr_generation", Name: "Generating PR description", Description: "Creating comprehensive PR description", Status: "pending"},
			{ID: "pr_creation", Name: "Creating pull request", Description: "Submitting PR to GitHub", Status: "pending"},
			{ID: "complete", Name: "Workflow complete", Description: "Process finished successfully", Status: "pending"},
		},
		CurrentStep: 0,
		StartTime:   time.Now(),
		TotalSteps:  9,
	}
}

// DisplayProgressHeaderWithBackground displays enhanced progress header with background updates
func (ui *UIManager) DisplayProgressHeaderWithBackground() {
	if ui.progressTracker == nil {
		ui.DisplayHeader()
		return
	}

	// Initial render
	fmt.Print("\033[2J\033[H") // Clear screen and move cursor to top
	ui.DisplayHeader()
	content := ui.generateHeaderContent()
	fmt.Print(content)
	fmt.Println()
	
	// Start background updates
	ui.startBackgroundHeaderUpdates()
}