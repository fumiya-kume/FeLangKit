package main

import (
	"fmt"
	"log"
	"os"

	"ccw/internal"
)

func main() {
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	// Handle command line arguments
	switch os.Args[1] {
	case "-h", "--help":
		printUsage()
		return
	case "list":
		internal.ListWorktrees()
		return
	case "doctor":
		internal.RunDiagnostics()
		return
	case "--init-config":
		initConfig()
		return
	case "--cleanup":
		internal.CleanupAllWorktrees()
		return
	case "--debug", "--verbose", "--trace":
		if len(os.Args) < 3 {
			fmt.Printf("Error: %s requires an issue URL\n", os.Args[1])
			printUsage()
			os.Exit(1)
		}
		internal.ProcessIssue(os.Args[2], os.Args[1])
		return
	default:
		// Default case: issue URL provided
		internal.ProcessIssue(os.Args[1], "")
	}
}

func printUsage() {
	fmt.Println(`CCW - Claude Code Workflow Manager

Usage:
  ccw <issue-url>                Process a GitHub issue
  ccw list                       List all worktrees
  ccw doctor                     Run system diagnostics
  ccw --init-config [filename]   Generate sample configuration
  ccw --cleanup                  Remove all worktrees
  ccw --debug <issue-url>        Run in debug mode
  ccw --verbose <issue-url>      Run in verbose mode
  ccw --trace <issue-url>        Run in trace mode
  ccw -h, --help                 Show this help message

Examples:
  ccw https://github.com/owner/repo/issues/123
  ccw list
  ccw --init-config my-config.yaml`)
}

func initConfig() {
	filename := "ccw.yaml"
	if len(os.Args) >= 3 {
		filename = os.Args[2]
	}

	if err := internal.GenerateSampleConfig(filename); err != nil {
		log.Fatalf("Failed to generate config file: %v", err)
	}
	fmt.Printf("Sample configuration file generated: %s\n", filename)
}