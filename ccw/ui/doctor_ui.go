package ui

import (
	tea "github.com/charmbracelet/bubbletea"
)

// RunDoctorUI starts the Bubble Tea doctor interface
// This is the main entry point for the Doctor UI functionality.
// All the implementation details have been separated into dedicated files:
// - doctor_model.go: Models, types, and business logic
// - doctor_view.go: View rendering and UI composition
// - doctor_styles.go: UI styling constants
// - doctor_checks.go: System check implementations
func RunDoctorUI() error {
	model := NewDoctorModel()
	p := tea.NewProgram(model, tea.WithAltScreen())

	_, err := p.Run()
	return err
}
