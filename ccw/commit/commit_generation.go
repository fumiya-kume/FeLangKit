package commit

import (
	"fmt"
	"os/exec"
	"strings"
	"time"
)

// Enhanced commit message generation with AI

// CommitMessageGenerator handles AI-powered commit message generation
type CommitMessageGenerator struct {
	claudeIntegration *ClaudeIntegration
	config           *Config
}

// CommitAnalysis contains information about changes for commit message generation
type CommitAnalysis struct {
	ModifiedFiles   []string            `json:"modified_files"`
	AddedFiles      []string            `json:"added_files"`
	DeletedFiles    []string            `json:"deleted_files"`
	DiffSummary     string              `json:"diff_summary"`
	FileTypes       map[string]int      `json:"file_types"`
	ChangeCategory  string              `json:"change_category"`
	Scope           string              `json:"scope"`
	IssueContext    *Issue             `json:"issue_context,omitempty"`
	ChangePatterns  []ChangePattern    `json:"change_patterns"`
	CommitMetadata  CommitMetadata     `json:"commit_metadata"`
}

// ChangePattern represents detected patterns in the changes
type ChangePattern struct {
	Type        string `json:"type"`        // "feature", "bugfix", "refactor", "test", "docs", "style"
	Description string `json:"description"`
	Confidence  float64 `json:"confidence"`
	Files       []string `json:"files"`
}

// CommitMetadata contains additional context for commit generation
type CommitMetadata struct {
	Author        string    `json:"author"`
	Timestamp     time.Time `json:"timestamp"`
	BranchName    string    `json:"branch_name"`
	IssueNumber   int       `json:"issue_number,omitempty"`
	WorktreePath  string    `json:"worktree_path"`
}

// GenerateEnhancedCommitMessage creates an AI-powered commit message
func (cmg *CommitMessageGenerator) GenerateEnhancedCommitMessage(worktreePath string, issue *Issue) (string, error) {
	// Analyze the changes
	analysis, err := cmg.analyzeChanges(worktreePath, issue)
	if err != nil {
		return "", fmt.Errorf("failed to analyze changes: %w", err)
	}
	
	// If no significant changes detected, use fallback
	if len(analysis.ModifiedFiles) == 0 && len(analysis.AddedFiles) == 0 && len(analysis.DeletedFiles) == 0 {
		return cmg.generateFallbackCommitMessage(issue), nil
	}
	
	// Generate AI-powered commit message
	aiMessage, err := cmg.generateAICommitMessage(analysis)
	if err != nil {
		// Fallback to rule-based generation if AI fails
		return cmg.generateRuleBasedCommitMessage(analysis), nil
	}
	
	return aiMessage, nil
}

// Analyze changes in the worktree
func (cmg *CommitMessageGenerator) analyzeChanges(worktreePath string, issue *Issue) (*CommitAnalysis, error) {
	analysis := &CommitAnalysis{
		FileTypes:      make(map[string]int),
		ChangePatterns: []ChangePattern{},
		IssueContext:   issue,
	}
	
	// Get file status
	statusCmd := createGitCommand([]string{"status", "--porcelain"}, worktreePath)
	statusOutput, err := statusCmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to get git status: %w", err)
	}
	
	// Parse file changes
	lines := strings.Split(strings.TrimSpace(string(statusOutput)), "\n")
	for _, line := range lines {
		if len(line) < 3 {
			continue
		}
		
		status := line[:2]
		filename := strings.TrimSpace(line[3:])
		
		// Categorize changes
		switch {
		case strings.Contains(status, "M"):
			analysis.ModifiedFiles = append(analysis.ModifiedFiles, filename)
		case strings.Contains(status, "A"):
			analysis.AddedFiles = append(analysis.AddedFiles, filename)
		case strings.Contains(status, "D"):
			analysis.DeletedFiles = append(analysis.DeletedFiles, filename)
		}
		
		// Count file types
		ext := getFileExtension(filename)
		analysis.FileTypes[ext]++
	}
	
	// Get diff summary
	diffCmd := createGitCommand([]string{"diff", "--staged", "--stat"}, worktreePath)
	diffOutput, err := diffCmd.Output()
	if err == nil {
		analysis.DiffSummary = string(diffOutput)
	}
	
	// Detect change patterns
	analysis.ChangePatterns = cmg.detectChangePatterns(analysis)
	
	// Determine change category and scope
	analysis.ChangeCategory = cmg.determineChangeCategory(analysis)
	analysis.Scope = cmg.determineScope(analysis)
	
	// Set metadata
	analysis.CommitMetadata = CommitMetadata{
		Timestamp:    time.Now(),
		WorktreePath: worktreePath,
	}
	
	if issue != nil {
		analysis.CommitMetadata.IssueNumber = issue.Number
	}
	
	// Get branch name
	branchCmd := createGitCommand([]string{"branch", "--show-current"}, worktreePath)
	if branchOutput, err := branchCmd.Output(); err == nil {
		analysis.CommitMetadata.BranchName = strings.TrimSpace(string(branchOutput))
	}
	
	return analysis, nil
}

// Detect patterns in changes
func (cmg *CommitMessageGenerator) detectChangePatterns(analysis *CommitAnalysis) []ChangePattern {
	patterns := []ChangePattern{}
	
	// Analyze file types and paths to detect patterns
	testFiles := 0
	sourceFiles := 0
	configFiles := 0
	docFiles := 0
	
	allFiles := append(append(analysis.ModifiedFiles, analysis.AddedFiles...), analysis.DeletedFiles...)
	
	for _, file := range allFiles {
		switch {
		case strings.Contains(strings.ToLower(file), "test"):
			testFiles++
		case strings.HasSuffix(file, ".go") || strings.HasSuffix(file, ".swift") || strings.HasSuffix(file, ".py"):
			sourceFiles++
		case strings.HasSuffix(file, ".yaml") || strings.HasSuffix(file, ".yml") || strings.HasSuffix(file, ".json") || strings.HasSuffix(file, ".toml"):
			configFiles++
		case strings.HasSuffix(file, ".md") || strings.HasSuffix(file, ".txt") || strings.HasSuffix(file, ".rst"):
			docFiles++
		}
	}
	
	// Detect test-related changes
	if testFiles > 0 {
		confidence := float64(testFiles) / float64(len(allFiles))
		patterns = append(patterns, ChangePattern{
			Type:        "test",
			Description: fmt.Sprintf("Test modifications (%d test files)", testFiles),
			Confidence:  confidence,
			Files:       filterFilesByPattern(allFiles, "test"),
		})
	}
	
	// Detect feature implementation
	if sourceFiles > 0 && len(analysis.AddedFiles) > 0 {
		confidence := float64(len(analysis.AddedFiles)) / float64(len(allFiles))
		if confidence > 0.3 {
			patterns = append(patterns, ChangePattern{
				Type:        "feature",
				Description: "New feature implementation",
				Confidence:  confidence,
				Files:       analysis.AddedFiles,
			})
		}
	}
	
	// Detect refactoring
	if len(analysis.ModifiedFiles) > len(analysis.AddedFiles)+len(analysis.DeletedFiles) {
		confidence := float64(len(analysis.ModifiedFiles)) / float64(len(allFiles))
		if confidence > 0.7 {
			patterns = append(patterns, ChangePattern{
				Type:        "refactor",
				Description: "Code refactoring",
				Confidence:  confidence,
				Files:       analysis.ModifiedFiles,
			})
		}
	}
	
	// Detect documentation changes
	if docFiles > 0 {
		confidence := float64(docFiles) / float64(len(allFiles))
		patterns = append(patterns, ChangePattern{
			Type:        "docs",
			Description: "Documentation updates",
			Confidence:  confidence,
			Files:       filterFilesByPattern(allFiles, ".md"),
		})
	}
	
	// Detect configuration changes
	if configFiles > 0 {
		confidence := float64(configFiles) / float64(len(allFiles))
		patterns = append(patterns, ChangePattern{
			Type:        "config",
			Description: "Configuration changes",
			Confidence:  confidence,
			Files:       filterFilesByPattern(allFiles, "config"),
		})
	}
	
	return patterns
}

// Determine overall change category
func (cmg *CommitMessageGenerator) determineChangeCategory(analysis *CommitAnalysis) string {
	if len(analysis.ChangePatterns) == 0 {
		return "chore"
	}
	
	// Find pattern with highest confidence
	highestConfidence := 0.0
	category := "chore"
	
	for _, pattern := range analysis.ChangePatterns {
		if pattern.Confidence > highestConfidence {
			highestConfidence = pattern.Confidence
			category = pattern.Type
		}
	}
	
	return category
}

// Determine scope of changes
func (cmg *CommitMessageGenerator) determineScope(analysis *CommitAnalysis) string {
	// Analyze file paths to determine scope
	scopes := make(map[string]int)
	allFiles := append(append(analysis.ModifiedFiles, analysis.AddedFiles...), analysis.DeletedFiles...)
	
	for _, file := range allFiles {
		parts := strings.Split(file, "/")
		if len(parts) > 1 {
			scope := parts[0]
			scopes[scope]++
		}
	}
	
	// Find most common scope
	maxCount := 0
	scope := ""
	for s, count := range scopes {
		if count > maxCount {
			maxCount = count
			scope = s
		}
	}
	
	// Return meaningful scope or empty
	if scope != "" && maxCount > 1 {
		return scope
	}
	
	return ""
}

// Generate AI-powered commit message using Claude
func (cmg *CommitMessageGenerator) generateAICommitMessage(analysis *CommitAnalysis) (string, error) {
	// For now, return a well-structured message based on analysis
	// Future enhancement: integrate with Claude API for true AI generation
	return cmg.generateStructuredCommitMessage(analysis), nil
}

// Build prompt for AI commit message generation
func (cmg *CommitMessageGenerator) buildCommitPrompt(analysis *CommitAnalysis) string {
	var prompt strings.Builder
	
	prompt.WriteString("Generate a concise, descriptive git commit message based on the following changes:\n\n")
	
	// Add file changes
	if len(analysis.ModifiedFiles) > 0 {
		prompt.WriteString(fmt.Sprintf("Modified files (%d): %s\n", len(analysis.ModifiedFiles), strings.Join(analysis.ModifiedFiles[:min(5, len(analysis.ModifiedFiles))], ", ")))
	}
	if len(analysis.AddedFiles) > 0 {
		prompt.WriteString(fmt.Sprintf("Added files (%d): %s\n", len(analysis.AddedFiles), strings.Join(analysis.AddedFiles[:min(5, len(analysis.AddedFiles))], ", ")))
	}
	if len(analysis.DeletedFiles) > 0 {
		prompt.WriteString(fmt.Sprintf("Deleted files (%d): %s\n", len(analysis.DeletedFiles), strings.Join(analysis.DeletedFiles[:min(3, len(analysis.DeletedFiles))], ", ")))
	}
	
	// Add diff summary
	if analysis.DiffSummary != "" {
		prompt.WriteString(fmt.Sprintf("\nDiff summary:\n%s\n", analysis.DiffSummary))
	}
	
	// Add detected patterns
	if len(analysis.ChangePatterns) > 0 {
		prompt.WriteString("\nDetected change patterns:\n")
		for _, pattern := range analysis.ChangePatterns {
			prompt.WriteString(fmt.Sprintf("- %s: %s (confidence: %.2f)\n", pattern.Type, pattern.Description, pattern.Confidence))
		}
	}
	
	// Add issue context
	if analysis.IssueContext != nil {
		prompt.WriteString(fmt.Sprintf("\nRelated to issue #%d: %s\n", analysis.IssueContext.Number, analysis.IssueContext.Title))
		if analysis.IssueContext.Body != "" && len(analysis.IssueContext.Body) < 200 {
			prompt.WriteString(fmt.Sprintf("Issue description: %s\n", analysis.IssueContext.Body))
		}
	}
	
	prompt.WriteString("\nGenerate a commit message that follows conventional commits format (type(scope): description).\n")
	prompt.WriteString("Keep the first line under 72 characters. Be specific about what changed and why.\n")
	
	return prompt.String()
}

// Generate structured commit message based on analysis
func (cmg *CommitMessageGenerator) generateStructuredCommitMessage(analysis *CommitAnalysis) string {
	var message strings.Builder
	
	// Build conventional commit format: type(scope): description
	commitType := analysis.ChangeCategory
	scope := analysis.Scope
	
	// Create subject line
	subject := fmt.Sprintf("%s", commitType)
	if scope != "" {
		subject = fmt.Sprintf("%s(%s)", commitType, scope)
	}
	
	// Generate description based on changes
	description := cmg.generateCommitDescription(analysis)
	subject = fmt.Sprintf("%s: %s", subject, description)
	
	message.WriteString(subject)
	message.WriteString("\n\n")
	
	// Add body with more details
	if len(analysis.ChangePatterns) > 0 {
		for _, pattern := range analysis.ChangePatterns {
			if pattern.Confidence > 0.5 {
				message.WriteString(fmt.Sprintf("- %s\n", pattern.Description))
			}
		}
		message.WriteString("\n")
	}
	
	// Add issue reference
	if analysis.IssueContext != nil {
		message.WriteString(fmt.Sprintf("Resolves #%d\n\n", analysis.IssueContext.Number))
	}
	
	// Add footer
	message.WriteString("🤖 Generated with [Claude Code](https://claude.ai/code)\n\n")
	message.WriteString("Co-Authored-By: Claude <noreply@anthropic.com>")
	
	return message.String()
}

// Generate commit description based on analysis
func (cmg *CommitMessageGenerator) generateCommitDescription(analysis *CommitAnalysis) string {
	totalFiles := len(analysis.ModifiedFiles) + len(analysis.AddedFiles) + len(analysis.DeletedFiles)
	
	// If we have issue context, use it
	if analysis.IssueContext != nil {
		title := analysis.IssueContext.Title
		if len(title) > 50 {
			title = title[:47] + "..."
		}
		return strings.ToLower(title)
	}
	
	// Generate based on change patterns
	if len(analysis.ChangePatterns) > 0 {
		primaryPattern := analysis.ChangePatterns[0]
		switch primaryPattern.Type {
		case "feature":
			return fmt.Sprintf("implement new feature across %d files", totalFiles)
		case "bugfix":
			return fmt.Sprintf("fix issue in %d files", totalFiles)
		case "refactor":
			return fmt.Sprintf("refactor code in %d files", totalFiles)
		case "test":
			return fmt.Sprintf("update tests (%d files)", totalFiles)
		case "docs":
			return fmt.Sprintf("update documentation (%d files)", totalFiles)
		case "config":
			return fmt.Sprintf("update configuration (%d files)", totalFiles)
		}
	}
	
	// Fallback based on file changes
	if len(analysis.AddedFiles) > len(analysis.ModifiedFiles) {
		return fmt.Sprintf("add %d new files", len(analysis.AddedFiles))
	} else if len(analysis.DeletedFiles) > 0 {
		return fmt.Sprintf("update and remove files (%d changed)", totalFiles)
	} else {
		return fmt.Sprintf("update %d files", len(analysis.ModifiedFiles))
	}
}

// Generate rule-based commit message (fallback)
func (cmg *CommitMessageGenerator) generateRuleBasedCommitMessage(analysis *CommitAnalysis) string {
	return cmg.generateStructuredCommitMessage(analysis)
}

// Generate fallback commit message
func (cmg *CommitMessageGenerator) generateFallbackCommitMessage(issue *Issue) string {
	if issue != nil {
		title := issue.Title
		if len(title) > 50 {
			title = title[:47] + "..."
		}
		return fmt.Sprintf("feat: %s\n\nResolves #%d\n\n🤖 Generated with [Claude Code](https://claude.ai/code)\n\nCo-Authored-By: Claude <noreply@anthropic.com>", 
			strings.ToLower(title), issue.Number)
	}
	
	return "chore: automated implementation via CCW\n\n🤖 Generated with [Claude Code](https://claude.ai/code)\n\nCo-Authored-By: Claude <noreply@anthropic.com>"
}

// Helper functions

func getFileExtension(filename string) string {
	parts := strings.Split(filename, ".")
	if len(parts) > 1 {
		return "." + parts[len(parts)-1]
	}
	return "no-ext"
}

func filterFilesByPattern(files []string, pattern string) []string {
	var filtered []string
	for _, file := range files {
		if strings.Contains(strings.ToLower(file), strings.ToLower(pattern)) {
			filtered = append(filtered, file)
		}
	}
	return filtered
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// Missing types and helper functions

// ClaudeIntegration placeholder
type ClaudeIntegration struct{}

// Config placeholder  
type Config struct{}

// Issue represents a GitHub issue
type Issue struct {
	Number int    `json:"number"`
	Title  string `json:"title"`
	Body   string `json:"body"`
}

// Helper function to create git commands
func createGitCommand(args []string, workDir string) *exec.Cmd {
	cmd := exec.Command("git", args...)
	cmd.Dir = workDir
	return cmd
}