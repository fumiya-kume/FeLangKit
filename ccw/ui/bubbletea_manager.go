package ui

import (
	"fmt"
	"os"
	"strings"

	"ccw/logging"
	"ccw/types"
	tea "github.com/charmbracelet/bubbletea"
	"golang.org/x/term"
)

// BubbleTeaManager handles Bubble Tea UI interactions
type BubbleTeaManager struct {
	ui      *UIManager
	program *tea.Program
	model   *AppModel
}

// NewBubbleTeaManager creates a new Bubble Tea manager
func NewBubbleTeaManager(ui *UIManager) *BubbleTeaManager {
	model := NewAppModel(ui)
	
	// Set up logging integration to send logs to UI buffer
	logging.SetUILogFunction(AddLogToBuffer)
	
	return &BubbleTeaManager{
		ui:    ui,
		model: &model,
	}
}

// RunInteractiveMenu runs the main interactive menu
func (btm *BubbleTeaManager) RunInteractiveMenu() error {
	// Enable UI mode to redirect logs to UI buffer
	logging.SetUIMode(true)
	defer logging.SetUIMode(false) // Restore console logging when done
	
	btm.program = tea.NewProgram(*btm.model, tea.WithAltScreen())
	
	finalModel, err := btm.program.Run()
	if err != nil {
		return fmt.Errorf("error running Bubble Tea program: %w", err)
	}

	// Update our model with the final state
	if appModel, ok := finalModel.(AppModel); ok {
		*btm.model = appModel
	}

	return nil
}

// DisplayIssueSelectionInteractive shows an interactive issue selection interface
func (btm *BubbleTeaManager) DisplayIssueSelectionInteractive(issues []*types.Issue) ([]*types.Issue, error) {
	// Enable UI mode to redirect logs to UI buffer
	logging.SetUIMode(true)
	defer logging.SetUIMode(false)
	
	// Set the issues in our model
	btm.model.SetIssues(issues)
	
	// Set state to issue selection
	btm.model.state = StateIssueSelection
	
	// Run the program
	btm.program = tea.NewProgram(*btm.model, tea.WithAltScreen())
	
	finalModel, err := btm.program.Run()
	if err != nil {
		return nil, fmt.Errorf("error running issue selection: %w", err)
	}

	// Extract selected issues from final model
	if appModel, ok := finalModel.(AppModel); ok {
		*btm.model = appModel
		return btm.model.GetSelectedIssues(), nil
	}

	return nil, fmt.Errorf("failed to get selected issues")
}

// DisplayProgressInteractive shows an interactive progress tracking interface
func (btm *BubbleTeaManager) DisplayProgressInteractive(steps []types.WorkflowStep) error {
	// Enable UI mode to redirect logs to UI buffer
	logging.SetUIMode(true)
	defer logging.SetUIMode(false)
	
	// Set the progress steps in our model
	btm.model.SetProgressSteps(steps)
	
	// Set state to progress tracking
	btm.model.state = StateProgressTracking
	
	// Run the program
	btm.program = tea.NewProgram(*btm.model, tea.WithAltScreen())
	
	_, err := btm.program.Run()
	if err != nil {
		return fmt.Errorf("error running progress tracking: %w", err)
	}

	return nil
}

// UpdateProgress sends a progress update to the running program
func (btm *BubbleTeaManager) UpdateProgress(stepID, status string) {
	if btm.program != nil {
		btm.program.Send(ProgressUpdateMsg{StepID: stepID, Status: status})
	}
}

// CompleteProgress signals that the progress is complete
func (btm *BubbleTeaManager) CompleteProgress() {
	if btm.program != nil {
		btm.program.Send(ProgressCompleteMsg{})
	}
}

// Quit the current program
func (btm *BubbleTeaManager) Quit() {
	if btm.program != nil {
		btm.program.Quit()
	}
}

// RunSimpleMenu runs a simple menu selection (non-Bubble Tea fallback)
func (btm *BubbleTeaManager) RunSimpleMenu(options []string, title string) (int, error) {
	fmt.Printf("\n%s\n", title)
	fmt.Println(string(make([]byte, len(title), len(title))))
	
	for i, option := range options {
		fmt.Printf("%d) %s\n", i+1, option)
	}
	
	fmt.Print("\nSelect an option: ")
	var choice int
	_, err := fmt.Scanf("%d", &choice)
	if err != nil {
		return -1, err
	}
	
	if choice < 1 || choice > len(options) {
		return -1, fmt.Errorf("invalid choice: %d", choice)
	}
	
	return choice - 1, nil
}

// Check if we can run Bubble Tea (terminal compatibility)
func (btm *BubbleTeaManager) CanRunInteractive() bool {
	// Check if we're in a terminal that supports Bubble Tea
	isTerminal := term.IsTerminal(int(os.Stdout.Fd()))
	
	// Additional checks for terminal capabilities
	hasColorSupport := os.Getenv("COLORTERM") != "" || 
		strings.Contains(strings.ToLower(os.Getenv("TERM")), "color")
	
	// If we detect modern terminal features, allow Bubble Tea even if IsTerminal fails
	modernTerminal := os.Getenv("TERM_PROGRAM") != "" && 
		(hasColorSupport || os.Getenv("COLORTERM") == "truecolor")
	
	// Debug info (can be removed later)
	if btm.ui.debugMode {
		fmt.Printf("Terminal compatibility check:\n")
		fmt.Printf("  IsTerminal: %v\n", isTerminal)
		fmt.Printf("  Color support: %v\n", hasColorSupport)
		fmt.Printf("  Modern terminal: %v\n", modernTerminal)
		fmt.Printf("  TERM_PROGRAM: %s\n", os.Getenv("TERM_PROGRAM"))
	}
	
	return isTerminal || modernTerminal
}

// Enhanced UIManager methods that integrate with Bubble Tea

// DisplayIssueSelectionEnhanced shows issue selection using the unified CCW app
func (ui *UIManager) DisplayIssueSelectionEnhanced(issues []*types.Issue) ([]*types.Issue, error) {
	app := ui.GetCCWApp()
	return app.RunIssueSelection(issues)
}

// DisplayProgressEnhanced shows progress tracking using the unified CCW app
func (ui *UIManager) DisplayProgressEnhanced(steps []types.WorkflowStep) error {
	app := ui.GetCCWApp()
	return app.RunProgressTracking(steps)
}

// RunMainMenuEnhanced shows main menu using the unified CCW app
func (ui *UIManager) RunMainMenuEnhanced() error {
	app := ui.GetCCWApp()
	return app.RunMainMenu()
}