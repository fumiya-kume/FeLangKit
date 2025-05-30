package main

import (
	"fmt"
	"log"
	"os"

	"ccw/app"
	"ccw/config"
	"ccw/ui"
)

func main() {
	if len(os.Args) < 2 {
		app.PrintUsage()
		os.Exit(1)
	}

	// Handle command line arguments
	switch os.Args[1] {
	case "-h", "--help":
		app.PrintUsage()
		return
	case "list":
		app.HandleListCommand()
		return
	case "doctor":
		app.HandleDoctorCommand()
		return
	case "--demo-ui":
		ui.RunBubbleTeaDemo()
		return
	case "--test-colors":
		ui.TestColorThemes()
		return
	case "--detect-terminal":
		ui.ShowTerminalDetectionInfo()
		return
	case "--demo-logs":
		ui.RunLogViewerDemo()
		return
	case "--console":
		handleConsoleMode()
		return
	case "--init-config":
		handleInitConfig()
		return
	case "--cleanup":
		handleCleanup()
		return
	case "--debug":
		handleDebugMode()
		return
	case "--verbose":
		handleVerboseMode()
		return
	case "--trace":
		handleTraceMode()
		return
	}

	// Default case: issue URL provided
	issueURL := os.Args[1]

	ccwApp, err := app.NewCCWApp()
	if err != nil {
		log.Fatalf("Failed to initialize application: %v", err)
	}
	defer ccwApp.Cleanup()

	if err := ccwApp.ExecuteWorkflow(issueURL); err != nil {
		log.Fatalf("Workflow failed: %v", err)
	}
}

// handleInitConfig generates sample configuration file
func handleInitConfig() {
	filename := "ccw.yaml"
	if len(os.Args) >= 3 {
		filename = os.Args[2]
	}

	if err := config.GenerateSampleConfig(filename); err != nil {
		log.Fatalf("Failed to generate config file: %v", err)
	}
	fmt.Printf("Sample configuration file generated: %s\n", filename)
}

// handleCleanup removes all worktrees
func handleCleanup() {
	ccwApp, err := app.NewCCWApp()
	if err != nil {
		log.Fatalf("Failed to initialize application: %v", err)
	}
	defer ccwApp.Cleanup()

	if err := ccwApp.CleanupAllWorktrees(); err != nil {
		log.Fatalf("Failed to cleanup worktrees: %v", err)
	}
}

// handleDebugMode runs workflow in debug mode
func handleDebugMode() {
	if len(os.Args) < 3 {
		fmt.Println("Error: --debug requires an issue URL")
		app.PrintUsage()
		os.Exit(1)
	}

	app.EnableDebugMode()
	issueURL := os.Args[2]

	ccwApp, err := app.NewCCWApp()
	if err != nil {
		log.Fatalf("Failed to initialize application: %v", err)
	}
	defer ccwApp.Cleanup()

	if err := ccwApp.ExecuteWorkflowWithRecovery(issueURL); err != nil {
		log.Fatalf("Workflow failed: %v", err)
	}
}

// handleVerboseMode runs workflow in verbose mode
func handleVerboseMode() {
	if len(os.Args) < 3 {
		fmt.Println("Error: --verbose requires an issue URL")
		app.PrintUsage()
		os.Exit(1)
	}

	app.EnableVerboseMode()
	issueURL := os.Args[2]

	ccwApp, err := app.NewCCWApp()
	if err != nil {
		log.Fatalf("Failed to initialize application: %v", err)
	}
	defer ccwApp.Cleanup()

	if err := ccwApp.ExecuteWorkflowWithRecovery(issueURL); err != nil {
		log.Fatalf("Workflow failed: %v", err)
	}
}

// handleTraceMode runs workflow in trace mode
func handleTraceMode() {
	if len(os.Args) < 3 {
		fmt.Println("Error: --trace requires an issue URL")
		app.PrintUsage()
		os.Exit(1)
	}

	app.EnableTraceMode()
	issueURL := os.Args[2]

	ccwApp, err := app.NewCCWApp()
	if err != nil {
		log.Fatalf("Failed to initialize application: %v", err)
	}
	defer ccwApp.Cleanup()

	if err := ccwApp.ExecuteWorkflowWithRecovery(issueURL); err != nil {
		log.Fatalf("Workflow failed: %v", err)
	}
}

// handleConsoleMode forces console mode for the workflow
func handleConsoleMode() {
	if len(os.Args) < 3 {
		fmt.Println("Error: --console requires an issue URL")
		app.PrintUsage()
		os.Exit(1)
	}

	// Set environment variable to force console mode
	os.Setenv("CCW_CONSOLE_MODE", "true")

	issueURL := os.Args[2]

	ccwApp, err := app.NewCCWApp()
	if err != nil {
		log.Fatalf("Failed to initialize application: %v", err)
	}
	defer ccwApp.Cleanup()

	if err := ccwApp.ExecuteWorkflow(issueURL); err != nil {
		log.Fatalf("Workflow failed: %v", err)
	}
}
