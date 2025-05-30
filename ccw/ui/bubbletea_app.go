package ui

import (
	"fmt"
	"os"
	"time"

	"ccw/logging"
	"ccw/types"
	tea "github.com/charmbracelet/bubbletea"
	"golang.org/x/term"
)

// CCWApp provides a unified Bubble Tea application entry point for all UI workflows
type CCWApp struct {
	ui           *UIManager
	program      *tea.Program
	model        *AppModel
	initialized  bool
	interactive  bool
	options      *CCWAppOptions
}

// CCWAppOptions configures the CCWApp behavior
type CCWAppOptions struct {
	ForceConsoleMode   bool
	EnableLogging      bool
	LogBufferSize      int
	Theme              string
	EnableAnimations   bool
	DebugMode          bool
	DefaultTimeout     time.Duration
	AltScreen          bool
}

// DefaultCCWAppOptions returns sensible defaults for CCWApp
func DefaultCCWAppOptions() *CCWAppOptions {
	return &CCWAppOptions{
		ForceConsoleMode: false,
		EnableLogging:    true,
		LogBufferSize:    1000,
		Theme:            "modern",
		EnableAnimations: true,
		DebugMode:        false,
		DefaultTimeout:   30 * time.Second,
		AltScreen:        true,
	}
}

// NewCCWApp creates a new unified CCW application
func NewCCWApp(options *CCWAppOptions) *CCWApp {
	if options == nil {
		options = DefaultCCWAppOptions()
	}

	// Create UI manager with specified options
	ui := NewUIManager(options.Theme, options.EnableAnimations, options.DebugMode)
	
	// Initialize the app
	app := &CCWApp{
		ui:          ui,
		options:     options,
		interactive: true,
	}

	// Determine if we can run interactively
	app.interactive = app.canRunInteractive()

	return app
}

// Initialize sets up the CCWApp for operation
func (app *CCWApp) Initialize() error {
	if app.initialized {
		return nil
	}

	// Set up logging integration if enabled
	if app.options.EnableLogging {
		InitLogBuffer(app.options.LogBufferSize)
		logging.SetUILogFunction(AddLogToBuffer)
	}

	// Create the main application model
	app.model = app.createAppModel()
	
	app.initialized = true
	return nil
}

// Run starts the unified CCW application with the specified workflow
func (app *CCWApp) Run(workflow CCWWorkflow) error {
	if !app.initialized {
		if err := app.Initialize(); err != nil {
			return fmt.Errorf("failed to initialize CCWApp: %w", err)
		}
	}

	// Check if we should use console mode
	if !app.interactive || app.options.ForceConsoleMode {
		return app.runConsoleMode(workflow)
	}

	// Run in interactive Bubble Tea mode
	return app.runInteractiveMode(workflow)
}

// RunMainMenu starts the main menu workflow
func (app *CCWApp) RunMainMenu() error {
	return app.Run(WorkflowMainMenu)
}

// RunIssueSelection starts the issue selection workflow
func (app *CCWApp) RunIssueSelection(issues []*types.Issue) ([]*types.Issue, error) {
	// Set issues in the model
	if !app.initialized {
		if err := app.Initialize(); err != nil {
			return nil, fmt.Errorf("failed to initialize CCWApp: %w", err)
		}
	}
	
	app.model.SetIssues(issues)
	
	if !app.interactive || app.options.ForceConsoleMode {
		return app.runIssueSelectionConsole(issues)
	}

	return app.runIssueSelectionInteractive()
}

// RunProgressTracking starts the progress tracking workflow
func (app *CCWApp) RunProgressTracking(steps []types.WorkflowStep) error {
	if !app.initialized {
		if err := app.Initialize(); err != nil {
			return fmt.Errorf("failed to initialize CCWApp: %w", err)
		}
	}
	
	app.model.SetProgressSteps(steps)
	
	if !app.interactive || app.options.ForceConsoleMode {
		return app.runProgressTrackingConsole(steps)
	}

	return app.runProgressTrackingInteractive()
}

// RunDoctorCheck starts the doctor diagnostics workflow
func (app *CCWApp) RunDoctorCheck() error {
	return app.Run(WorkflowDoctorCheck)
}

// runInteractiveMode runs the app in full Bubble Tea interactive mode
func (app *CCWApp) runInteractiveMode(workflow CCWWorkflow) error {
	// Enable UI mode for logging
	if app.options.EnableLogging {
		logging.SetUIMode(true)
		defer logging.SetUIMode(false)
	}

	// Set the initial state based on workflow
	app.setInitialState(workflow)

	// Create Bubble Tea program
	programOptions := []tea.ProgramOption{}
	if app.options.AltScreen {
		programOptions = append(programOptions, tea.WithAltScreen())
	}
	
	app.program = tea.NewProgram(*app.model, programOptions...)

	// Run the program
	finalModel, err := app.program.Run()
	if err != nil {
		return fmt.Errorf("error running Bubble Tea program: %w", err)
	}

	// Update model with final state
	if appModel, ok := finalModel.(AppModel); ok {
		*app.model = appModel
	}

	return nil
}

// runConsoleMode runs the app in console-friendly mode
func (app *CCWApp) runConsoleMode(workflow CCWWorkflow) error {
	switch workflow {
	case WorkflowMainMenu:
		return app.runMainMenuConsole()
	case WorkflowDoctorCheck:
		return app.runDoctorCheckConsole()
	default:
		return fmt.Errorf("workflow %v not supported in console mode", workflow)
	}
}

// setInitialState configures the app model for the specified workflow
func (app *CCWApp) setInitialState(workflow CCWWorkflow) {
	switch workflow {
	case WorkflowMainMenu:
		app.model.state = StateMainMenu
	case WorkflowIssueSelection:
		app.model.state = StateIssueSelection
	case WorkflowProgressTracking:
		app.model.state = StateProgressTracking
	case WorkflowDoctorCheck:
		app.model.state = StateDoctorCheck
		app.model.doctorModel = NewDoctorModel()
	}
}

// createAppModel creates and configures the main application model
func (app *CCWApp) createAppModel() *AppModel {
	model := NewAppModel(app.ui)
	return &model
}

// canRunInteractive determines if the app can run in interactive mode
func (app *CCWApp) canRunInteractive() bool {
	// Check environment variables that force console mode
	if app.options.ForceConsoleMode ||
		os.Getenv("CCW_CONSOLE_MODE") == "true" ||
		os.Getenv("CI") == "true" ||
		os.Getenv("GITHUB_ACTIONS") == "true" ||
		os.Getenv("GITLAB_CI") == "true" ||
		os.Getenv("JENKINS_URL") != "" {
		return false
	}

	// Check terminal capabilities
	isTerminal := term.IsTerminal(int(os.Stdout.Fd()))
	
	// Additional checks for modern terminals
	hasColorSupport := os.Getenv("COLORTERM") != "" ||
		os.Getenv("TERM_PROGRAM") != ""

	if app.options.DebugMode {
		app.ui.Debug(fmt.Sprintf("Interactive mode check: terminal=%v, color=%v", 
			isTerminal, hasColorSupport))
	}

	return isTerminal || hasColorSupport
}

// Update methods for external progress updates

// UpdateProgress sends a progress update to the running program
func (app *CCWApp) UpdateProgress(stepID, status string) {
	if app.program != nil {
		app.program.Send(ProgressUpdateMsg{StepID: stepID, Status: status})
	}
}

// CompleteProgress signals that the progress workflow is complete
func (app *CCWApp) CompleteProgress() {
	if app.program != nil {
		app.program.Send(ProgressCompleteMsg{})
	}
}

// Quit terminates the current program gracefully
func (app *CCWApp) Quit() {
	if app.program != nil {
		app.program.Quit()
	}
}

// Console mode implementations

// runMainMenuConsole runs main menu in console mode
func (app *CCWApp) runMainMenuConsole() error {
	app.ui.DisplayHeader()
	
	options := []string{
		"Select Issues to Process",
		"View Repository Issues", 
		"Start Workflow",
		"Doctor (System Diagnostics)",
		"Exit",
	}

	btm := NewBubbleTeaManager(app.ui)
	choice, err := btm.RunSimpleMenu(options, "CCW - Claude Code Worktree")
	if err != nil {
		return err
	}

	switch choice {
	case 0:
		app.ui.Info("Issue selection mode selected")
	case 1:
		app.ui.Info("Repository view mode selected")
	case 2:
		app.ui.Info("Starting workflow...")
	case 3:
		return app.runDoctorCheckConsole()
	case 4:
		app.ui.Info("Exiting...")
		os.Exit(0)
	}

	return nil
}

// runDoctorCheckConsole runs doctor check in console mode
func (app *CCWApp) runDoctorCheckConsole() error {
	return RunDoctorUI()
}

// runIssueSelectionConsole runs issue selection in console mode
func (app *CCWApp) runIssueSelectionConsole(issues []*types.Issue) ([]*types.Issue, error) {
	return app.ui.DisplayIssueSelection(issues)
}

// runProgressTrackingConsole runs progress tracking in console mode
func (app *CCWApp) runProgressTrackingConsole(steps []types.WorkflowStep) error {
	app.ui.InitializeProgress()
	app.ui.DisplayProgressHeaderWithBackground()
	return nil
}

// runIssueSelectionInteractive runs issue selection in interactive mode
func (app *CCWApp) runIssueSelectionInteractive() ([]*types.Issue, error) {
	// Enable UI mode for logging
	if app.options.EnableLogging {
		logging.SetUIMode(true)
		defer logging.SetUIMode(false)
	}

	// Set state to issue selection
	app.model.state = StateIssueSelection

	// Create and run program
	programOptions := []tea.ProgramOption{}
	if app.options.AltScreen {
		programOptions = append(programOptions, tea.WithAltScreen())
	}
	
	app.program = tea.NewProgram(*app.model, programOptions...)

	finalModel, err := app.program.Run()
	if err != nil {
		return nil, fmt.Errorf("error running issue selection: %w", err)
	}

	// Extract selected issues
	if appModel, ok := finalModel.(AppModel); ok {
		*app.model = appModel
		return app.model.GetSelectedIssues(), nil
	}

	return nil, fmt.Errorf("failed to get selected issues")
}

// runProgressTrackingInteractive runs progress tracking in interactive mode
func (app *CCWApp) runProgressTrackingInteractive() error {
	// Enable UI mode for logging
	if app.options.EnableLogging {
		logging.SetUIMode(true)
		defer logging.SetUIMode(false)
	}

	// Set state to progress tracking
	app.model.state = StateProgressTracking

	// Create and run program
	programOptions := []tea.ProgramOption{}
	if app.options.AltScreen {
		programOptions = append(programOptions, tea.WithAltScreen())
	}
	
	app.program = tea.NewProgram(*app.model, programOptions...)

	_, err := app.program.Run()
	if err != nil {
		return fmt.Errorf("error running progress tracking: %w", err)
	}

	return nil
}

// Workflow types for unified entry points
type CCWWorkflow int

const (
	WorkflowMainMenu CCWWorkflow = iota
	WorkflowIssueSelection
	WorkflowProgressTracking
	WorkflowDoctorCheck
)

// String returns a human-readable name for the workflow
func (w CCWWorkflow) String() string {
	switch w {
	case WorkflowMainMenu:
		return "Main Menu"
	case WorkflowIssueSelection:
		return "Issue Selection"
	case WorkflowProgressTracking:
		return "Progress Tracking"
	case WorkflowDoctorCheck:
		return "Doctor Check"
	default:
		return "Unknown"
	}
}

// Utility function to create a CCWApp with defaults
func NewDefaultCCWApp() *CCWApp {
	return NewCCWApp(DefaultCCWAppOptions())
}

// BackToMainMenuMsg for returning to main menu from sub-workflows
type BackToMainMenuMsg struct{}