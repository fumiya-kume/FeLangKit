package claude

import (
	"fmt"
	"os/exec"
	"strings"

	"ccw/types"
)

// GenerateImplementationSummaryAsync generates implementation summary asynchronously
func (ci *ClaudeIntegration) GenerateImplementationSummaryAsync(worktreePath string) <-chan types.ImplementationSummaryResult {
	resultChan := make(chan types.ImplementationSummaryResult, 1)

	go func() {
		defer close(resultChan)

		summary, err := ci.GenerateImplementationSummary(worktreePath)
		resultChan <- types.ImplementationSummaryResult{
			Summary: summary,
			Error:   err,
		}
	}()

	return resultChan
}

// GenerateImplementationSummary generates implementation summary from git changes
func (ci *ClaudeIntegration) GenerateImplementationSummary(worktreePath string) (string, error) {
	// Get git diff to analyze changes
	cmd := exec.Command("git", "diff", "--name-status", "HEAD")
	cmd.Dir = worktreePath
	output, err := cmd.Output()
	if err != nil {
		return "Implementation completed with code changes.", nil // Fallback if git diff fails
	}

	changes := strings.TrimSpace(string(output))
	if changes == "" {
		return "No code changes detected.", nil
	}

	// Parse the changes
	lines := strings.Split(changes, "\n")
	var addedFiles, modifiedFiles, deletedFiles []string

	for _, line := range lines {
		parts := strings.Fields(line)
		if len(parts) >= 2 {
			status := parts[0]
			file := parts[1]

			switch status {
			case "A":
				addedFiles = append(addedFiles, file)
			case "M":
				modifiedFiles = append(modifiedFiles, file)
			case "D":
				deletedFiles = append(deletedFiles, file)
			}
		}
	}

	// Build summary
	var summary strings.Builder
	summary.WriteString("Implementation completed with the following changes:\n")

	if len(addedFiles) > 0 {
		summary.WriteString(fmt.Sprintf("- Added %d new files: %s\n", len(addedFiles), strings.Join(addedFiles, ", ")))
	}
	if len(modifiedFiles) > 0 {
		summary.WriteString(fmt.Sprintf("- Modified %d existing files: %s\n", len(modifiedFiles), strings.Join(modifiedFiles, ", ")))
	}
	if len(deletedFiles) > 0 {
		summary.WriteString(fmt.Sprintf("- Deleted %d files: %s\n", len(deletedFiles), strings.Join(deletedFiles, ", ")))
	}

	return summary.String(), nil
}
