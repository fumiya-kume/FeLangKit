package ui

import "fmt"

// Logging methods for UIManager

// Info displays an informational message
func (ui *UIManager) Info(msg string) {
	fmt.Printf("%s %s\n", ui.infoColor("[INFO]"), msg)
}

// Success displays a success message
func (ui *UIManager) Success(msg string) {
	fmt.Printf("%s %s\n", ui.successColor("[SUCCESS]"), msg)
}

// Warning displays a warning message
func (ui *UIManager) Warning(msg string) {
	fmt.Printf("%s %s\n", ui.warningColor("[WARNING]"), msg)
}

// Error displays an error message
func (ui *UIManager) Error(msg string) {
	fmt.Printf("%s %s\n", ui.errorColorFunc("[ERROR]"), msg)
}

// Debug displays a debug message if debug mode is enabled
func (ui *UIManager) Debug(msg string) {
	if ui.debugMode {
		fmt.Printf("%s %s\n", ui.accentColor("[DEBUG]"), msg)
	}
}