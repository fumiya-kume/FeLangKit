package ui

// This file provides backward compatibility for terminal UI functionality.
// The functionality has been refactored into smaller, focused modules:
//
// - ui_manager.go:     Core UIManager struct and initialization
// - ui_logging.go:     Logging methods (Info, Success, Warning, Error, Debug)
// - ui_validation.go:  Validation display functionality
// - ui_progress.go:    Progress management and display
// - ui_display.go:     General display methods
//
// All public APIs remain unchanged to maintain backward compatibility.
//
// The original 456-line file has been split into focused modules for better
// maintainability and organization while preserving all existing functionality.