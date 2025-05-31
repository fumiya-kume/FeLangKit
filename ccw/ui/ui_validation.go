package ui

import (
	"fmt"
	"strings"
	"time"

	"ccw/types"
)

// DisplayValidationResults displays validation results with visual formatting
func (ui *UIManager) DisplayValidationResults(result *types.ValidationResult) {
	title := ui.getConsoleChar("🔍 Validation Results", "Validation Results")
	separator := ui.getConsoleChar("─", "-")
	
	fmt.Println(ui.primaryColor(title))
	fmt.Println(strings.Repeat(separator, 50))

	if result.LintResult != nil {
		passedIcon := ui.getConsoleChar("✅", "[PASS]")
		failedIcon := ui.getConsoleChar("❌", "[FAIL]")
		
		status := passedIcon + " PASSED"
		color := ui.successColor
		if !result.LintResult.Success {
			status = failedIcon + " FAILED"
			color = ui.errorColorFunc
		}
		fmt.Printf("SwiftLint: %s", color(status))
		if result.LintResult.AutoFixed {
			fmt.Print(ui.infoColor(" (auto-fixed)"))
		}
		fmt.Println()
	}

	if result.BuildResult != nil {
		passedIcon := ui.getConsoleChar("✅", "[PASS]")
		failedIcon := ui.getConsoleChar("❌", "[FAIL]")
		
		status := passedIcon + " PASSED"
		color := ui.successColor
		if !result.BuildResult.Success {
			status = failedIcon + " FAILED"
			color = ui.errorColorFunc
		}
		fmt.Printf("Build:     %s\n", color(status))
	}

	if result.TestResult != nil {
		passedIcon := ui.getConsoleChar("✅", "[PASS]")
		failedIcon := ui.getConsoleChar("❌", "[FAIL]")
		
		status := passedIcon + " PASSED"
		color := ui.successColor
		if !result.TestResult.Success {
			status = failedIcon + " FAILED"
			color = ui.errorColorFunc
		}
		fmt.Printf("Tests:     %s", color(status))
		if result.TestResult.TestCount > 0 {
			fmt.Printf(ui.infoColor(" (%d passed, %d failed)"), result.TestResult.Passed, result.TestResult.Failed)
		}
		fmt.Println()
	}

	// Display detailed error information if there are errors
	if len(result.Errors) > 0 {
		fmt.Printf("\n%s\n", ui.errorColorFunc("Error Details:"))
		for i, err := range result.Errors {
			ui.displayValidationError(err, i+1)
		}
	}

	fmt.Printf("\nDuration: %s\n\n", ui.infoColor(result.Duration.Round(time.Millisecond)))
}

// displayValidationError shows detailed information about a single validation error
func (ui *UIManager) displayValidationError(err types.ValidationError, errorNumber int) {
	errorIcon := ui.getConsoleChar("⚠️", "[ERR]")
	
	// Display error header
	fmt.Printf("%s %s %d: [%s] %s\n", 
		errorIcon, 
		ui.errorColorFunc("Error"), 
		errorNumber, 
		ui.warningColor(strings.ToUpper(err.Type)), 
		ui.primaryColor(err.Message))

	// Display cause information if available
	if err.Cause != nil {
		indent := "  "
		
		if err.Cause.Command != "" {
			cmdIcon := ui.getConsoleChar("🔧", "[CMD]")
			fmt.Printf("%s%s %s: %s\n", indent, cmdIcon, ui.infoColor("Command"), ui.accentColor(err.Cause.Command))
		}
		
		if err.Cause.ExitCode != 0 {
			exitIcon := ui.getConsoleChar("💥", "[EXIT]")
			fmt.Printf("%s%s %s: %s\n", indent, exitIcon, ui.infoColor("Exit Code"), ui.errorColorFunc(fmt.Sprintf("%d", err.Cause.ExitCode)))
		}
		
		if err.Cause.RootError != "" {
			causeIcon := ui.getConsoleChar("🔍", "[CAUSE]")
			fmt.Printf("%s%s %s: %s\n", indent, causeIcon, ui.infoColor("Root Cause"), ui.accentColor(err.Cause.RootError))
		}
		
		if err.Cause.Stderr != "" && err.Cause.Stderr != err.Cause.RootError {
			stderrIcon := ui.getConsoleChar("📄", "[STDERR]")
			fmt.Printf("%s%s %s:\n%s%s\n", indent, stderrIcon, ui.infoColor("Error Output"), indent+"  ", ui.accentColor(err.Cause.Stderr))
		}
		
		if len(err.Cause.Context) > 0 {
			ctxIcon := ui.getConsoleChar("📋", "[CTX]")
			fmt.Printf("%s%s %s:\n", indent, ctxIcon, ui.infoColor("Context"))
			for key, value := range err.Cause.Context {
				fmt.Printf("%s  %s: %s\n", indent, ui.warningColor(key), ui.accentColor(value))
			}
		}
	}
	
	// Add recovery suggestion if recoverable
	if err.Recoverable {
		recoveryIcon := ui.getConsoleChar("🔄", "[FIX]")
		fmt.Printf("  %s %s: This error may be automatically recoverable\n", recoveryIcon, ui.successColor("Recovery"))
	}
	
	fmt.Println() // Add spacing between errors
}