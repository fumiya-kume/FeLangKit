package internal

import (
	"bufio"
	"fmt"
	"os"
	"strings"
)

// UI handles all user interface interactions
type UI struct {
	spinner *Spinner
}

// NewUI creates a new UI instance
func NewUI() *UI {
	return &UI{
		spinner: NewSpinner(),
	}
}

// ShowStartup displays the startup message
func (ui *UI) ShowStartup(issueURL string) {
	fmt.Println("\n🚀 CCW - Claude Code Workflow Manager")
	fmt.Println("=====================================")
	fmt.Printf("Processing issue: %s\n\n", issueURL)
}

// UpdateStatus updates the current status with a spinner
func (ui *UI) UpdateStatus(message string) {
	ui.spinner.Start(message)
}

// ShowError displays an error message
func (ui *UI) ShowError(context string, err error) {
	ui.spinner.Stop()
	fmt.Printf("\n❌ %s: %v\n", context, err)
}

// ShowWarning displays a warning message
func (ui *UI) ShowWarning(message string) {
	ui.spinner.Stop()
	fmt.Printf("\n⚠️  %s\n", message)
}

// ShowSuccess displays a success message
func (ui *UI) ShowSuccess(message string) {
	ui.spinner.Stop()
	fmt.Printf("\n✅ %s\n", message)
}

// ShowIssueInfo displays issue information
func (ui *UI) ShowIssueInfo(number int, title string) {
	ui.spinner.Stop()
	fmt.Printf("📋 Issue #%d: %s\n", number, title)
}

// ShowPRCreated displays PR creation success
func (ui *UI) ShowPRCreated(url string) {
	ui.spinner.Stop()
	fmt.Printf("\n🔗 Pull Request created: %s\n", url)
}

// ShowValidationResults displays validation results
func (ui *UI) ShowValidationResults(result *ValidationResult) {
	ui.spinner.Stop()
	fmt.Println("\n📊 Validation Results:")

	if result.LintPassed {
		fmt.Println("  ✅ SwiftLint: Passed")
	} else {
		fmt.Println("  ❌ SwiftLint: Failed")
		if result.LintOutput != "" {
			fmt.Printf("     %s\n", strings.ReplaceAll(result.LintOutput, "\n", "\n     "))
		}
	}

	if result.BuildPassed {
		fmt.Println("  ✅ Build: Passed")
	} else {
		fmt.Println("  ❌ Build: Failed")
	}

	if result.TestsPassed {
		fmt.Println("  ✅ Tests: Passed")
	} else {
		fmt.Println("  ❌ Tests: Failed")
	}
}

// ConfirmContinue asks the user to confirm continuation
func (ui *UI) ConfirmContinue(prompt string) bool {
	fmt.Printf("\n%s (y/N): ", prompt)

	reader := bufio.NewReader(os.Stdin)
	response, err := reader.ReadString('\n')
	if err != nil {
		return false
	}

	response = strings.ToLower(strings.TrimSpace(response))
	return response == "y" || response == "yes"
}

// Spinner provides a simple loading animation
type Spinner struct {
	active  bool
	message string
	done    chan bool
}

// NewSpinner creates a new spinner
func NewSpinner() *Spinner {
	return &Spinner{
		done: make(chan bool),
	}
}

// Start begins the spinner animation
func (s *Spinner) Start(message string) {
	s.Stop() // Stop any existing spinner

	s.active = true
	s.message = message

	// For simplicity, just print the message with a status indicator
	fmt.Printf("⏳ %s...", message)
}

// Stop stops the spinner animation
func (s *Spinner) Stop() {
	if s.active {
		s.active = false
		fmt.Println(" ✓")
	}
}

// Progress bar for long operations
type ProgressBar struct {
	total   int
	current int
	width   int
}

// NewProgressBar creates a new progress bar
func NewProgressBar(total int) *ProgressBar {
	return &ProgressBar{
		total: total,
		width: 40,
	}
}

// Update updates the progress bar
func (p *ProgressBar) Update(current int) {
	p.current = current
	percentage := float64(current) / float64(p.total)
	filled := int(percentage * float64(p.width))

	bar := strings.Repeat("█", filled) + strings.Repeat("░", p.width-filled)
	fmt.Printf("\r[%s] %3.0f%%", bar, percentage*100)

	if current >= p.total {
		fmt.Println()
	}
}

// Color functions for terminal output
const (
	ColorReset  = "\033[0m"
	ColorRed    = "\033[31m"
	ColorGreen  = "\033[32m"
	ColorYellow = "\033[33m"
	ColorBlue   = "\033[34m"
	ColorPurple = "\033[35m"
	ColorCyan   = "\033[36m"
	ColorGray   = "\033[37m"
	ColorWhite  = "\033[97m"
)

// Colorize returns colored text for terminal output
func Colorize(text, color string) string {
	// Check if terminal supports colors
	if os.Getenv("NO_COLOR") != "" {
		return text
	}
	return color + text + ColorReset
}

// Status box for displaying structured information
type StatusBox struct {
	title string
	items []StatusItem
}

type StatusItem struct {
	Label string
	Value string
	Color string
}

// NewStatusBox creates a new status box
func NewStatusBox(title string) *StatusBox {
	return &StatusBox{
		title: title,
		items: []StatusItem{},
	}
}

// AddItem adds an item to the status box
func (s *StatusBox) AddItem(label, value, color string) {
	s.items = append(s.items, StatusItem{
		Label: label,
		Value: value,
		Color: color,
	})
}

// Display shows the status box
func (s *StatusBox) Display() {
	width := 60
	fmt.Println(strings.Repeat("─", width))
	fmt.Printf("│ %-*s │\n", width-4, s.title)
	fmt.Println(strings.Repeat("─", width))

	for _, item := range s.items {
		value := item.Value
		if item.Color != "" {
			value = Colorize(value, item.Color)
		}
		fmt.Printf("│ %-20s: %-*s │\n", item.Label, width-26, value)
	}

	fmt.Println(strings.Repeat("─", width))
}
