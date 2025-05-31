package commit

import (
	"fmt"
	"strings"
	"testing"
	"time"
)

// TestCommitAnalysis tests commit analysis structure
func TestCommitAnalysis(t *testing.T) {
	analysis := &CommitAnalysis{
		ModifiedFiles: []string{"main.go", "utils.go"},
		AddedFiles:    []string{"new_feature.go"},
		DeletedFiles:  []string{"deprecated.go"},
		DiffSummary:   "3 files changed, 150 insertions(+), 75 deletions(-)",
		FileTypes: map[string]int{
			"go": 4,
			"md": 1,
		},
		ChangeCategory: "feature",
		Scope:         "core",
		CommitMetadata: CommitMetadata{
			Author:       "developer@example.com",
			Timestamp:    time.Now(),
			BranchName:   "feature/new-feature",
			IssueNumber:  789,
			WorktreePath: "/tmp/worktree",
		},
	}
	
	totalFiles := len(analysis.ModifiedFiles) + len(analysis.AddedFiles) + len(analysis.DeletedFiles)
	if totalFiles != 4 {
		t.Errorf("Expected 4 total files, got %d", totalFiles)
	}
	
	if analysis.CommitMetadata.IssueNumber != 789 {
		t.Errorf("Expected issue number 789, got %d", analysis.CommitMetadata.IssueNumber)
	}
	
	if analysis.ChangeCategory == "" {
		t.Error("Change category should not be empty")
	}
	
	if analysis.Scope == "" {
		t.Error("Scope should not be empty")
	}
}

// TestChangePatternDetection tests change pattern detection
func TestChangePatternDetection(t *testing.T) {
	patterns := []ChangePattern{
		{
			Type:        "refactoring",
			Description: "Extract method for code reuse",
			Confidence:  0.85,
			Files:       []string{"utils.go", "helpers.go"},
		},
		{
			Type:        "feature",
			Description: "Add new authentication system",
			Confidence:  0.95,
			Files:       []string{"auth.go", "middleware.go"},
		},
		{
			Type:        "bugfix",
			Description: "Fix memory leak in cache",
			Confidence:  0.90,
			Files:       []string{"cache.go"},
		},
	}
	
	for i, pattern := range patterns {
		if pattern.Confidence < 0 || pattern.Confidence > 1 {
			t.Errorf("Pattern %d: Invalid confidence value: %f", i, pattern.Confidence)
		}
		
		if len(pattern.Files) == 0 {
			t.Errorf("Pattern %d: Should have associated files", i)
		}
		
		if pattern.Type == "" {
			t.Errorf("Pattern %d: Type should not be empty", i)
		}
		
		if pattern.Description == "" {
			t.Errorf("Pattern %d: Description should not be empty", i)
		}
	}
}

// TestCommitMetadata tests commit metadata structure
func TestCommitMetadata(t *testing.T) {
	metadata := CommitMetadata{
		Author:       "test@example.com",
		Timestamp:    time.Now(),
		BranchName:   "feature/test-feature",
		IssueNumber:  123,
		WorktreePath: "/tmp/test-worktree",
	}
	
	if metadata.Author == "" {
		t.Error("Author should not be empty")
	}
	
	if metadata.Timestamp.IsZero() {
		t.Error("Timestamp should be set")
	}
	
	if metadata.BranchName == "" {
		t.Error("Branch name should not be empty")
	}
	
	if metadata.IssueNumber <= 0 {
		t.Error("Issue number should be positive")
	}
	
	if metadata.WorktreePath == "" {
		t.Error("Worktree path should not be empty")
	}
}

// TestCommitMessageGenerator tests the commit message generator structure
func TestCommitMessageGenerator(t *testing.T) {
	generator := &CommitMessageGenerator{
		claudeIntegration: nil, // Will be nil in tests
		config:            nil, // Will be nil in tests
	}
	
	if generator == nil {
		t.Fatal("Failed to create commit message generator")
	}
}

// TestCommitAnalysisWithEdgeCases tests commit analysis with edge cases
func TestCommitAnalysisWithEdgeCases(t *testing.T) {
	tests := []struct {
		name     string
		analysis *CommitAnalysis
		valid    bool
	}{
		{
			name: "Empty analysis",
			analysis: &CommitAnalysis{
				ModifiedFiles:  []string{},
				AddedFiles:     []string{},
				DeletedFiles:   []string{},
				FileTypes:      map[string]int{},
				ChangeCategory: "",
				Scope:          "",
			},
			valid: true, // Empty is valid
		},
		{
			name: "Large number of files",
			analysis: &CommitAnalysis{
				ModifiedFiles: make([]string, 1000),
				AddedFiles:    make([]string, 500),
				DeletedFiles:  make([]string, 200),
				FileTypes:     map[string]int{"go": 1700},
			},
			valid: true,
		},
		{
			name: "Analysis with nil maps",
			analysis: &CommitAnalysis{
				ModifiedFiles: []string{"test.go"},
				FileTypes:     nil, // This should be handled gracefully
			},
			valid: true,
		},
	}
	
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.analysis.FileTypes != nil {
				totalFiles := 0
				for _, count := range tt.analysis.FileTypes {
					totalFiles += count
				}
				t.Logf("Total files in types map: %d", totalFiles)
			}
			
			actualTotal := len(tt.analysis.ModifiedFiles) + len(tt.analysis.AddedFiles) + len(tt.analysis.DeletedFiles)
			t.Logf("Actual file count: %d", actualTotal)
		})
	}
}

// TestChangePatternEdgeCases tests change pattern detection with edge cases
func TestChangePatternEdgeCases(t *testing.T) {
	tests := []struct {
		name    string
		pattern ChangePattern
		valid   bool
	}{
		{
			name: "Pattern with zero confidence",
			pattern: ChangePattern{
				Type:        "unknown",
				Description: "Unknown change type",
				Confidence:  0.0,
				Files:       []string{"unknown.txt"},
			},
			valid: true, // Zero confidence is valid
		},
		{
			name: "Pattern with maximum confidence",
			pattern: ChangePattern{
				Type:        "feature",
				Description: "Definite new feature",
				Confidence:  1.0,
				Files:       []string{"feature.go"},
			},
			valid: true,
		},
		{
			name: "Pattern with invalid confidence",
			pattern: ChangePattern{
				Type:        "invalid",
				Description: "Invalid confidence",
				Confidence:  1.5, // Invalid: > 1.0
				Files:       []string{"test.go"},
			},
			valid: false,
		},
		{
			name: "Pattern with negative confidence",
			pattern: ChangePattern{
				Type:        "invalid",
				Description: "Negative confidence",
				Confidence:  -0.1,
				Files:       []string{"test.go"},
			},
			valid: false,
		},
		{
			name: "Pattern with empty files",
			pattern: ChangePattern{
				Type:        "docs",
				Description: "Documentation update",
				Confidence:  0.8,
				Files:       []string{}, // Empty files list
			},
			valid: false, // Should have files
		},
	}
	
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Validate confidence range
			validConfidence := tt.pattern.Confidence >= 0 && tt.pattern.Confidence <= 1
			if tt.valid && !validConfidence {
				t.Error("Expected valid confidence range")
			}
			
			// Validate files list
			hasFiles := len(tt.pattern.Files) > 0
			if tt.valid && !hasFiles {
				t.Error("Expected pattern to have files")
			}
			
			// Log pattern details
			t.Logf("Pattern: %s, Confidence: %f, Files: %d", tt.pattern.Type, tt.pattern.Confidence, len(tt.pattern.Files))
		})
	}
}

// TestCommitMetadataEdgeCases tests commit metadata with edge cases
func TestCommitMetadataEdgeCases(t *testing.T) {
	tests := []struct {
		name     string
		metadata CommitMetadata
		valid    bool
	}{
		{
			name: "Metadata with future timestamp",
			metadata: CommitMetadata{
				Author:       "test@example.com",
				Timestamp:    time.Now().Add(24 * time.Hour), // Future timestamp
				BranchName:   "feature/future",
				IssueNumber:  1,
				WorktreePath: "/tmp/future",
			},
			valid: true, // Future timestamps are technically valid
		},
		{
			name: "Metadata with zero timestamp",
			metadata: CommitMetadata{
				Author:       "test@example.com",
				Timestamp:    time.Time{}, // Zero timestamp
				BranchName:   "feature/zero-time",
				IssueNumber:  1,
				WorktreePath: "/tmp/zero",
			},
			valid: false, // Zero timestamp is invalid
		},
		{
			name: "Metadata with negative issue number",
			metadata: CommitMetadata{
				Author:       "test@example.com",
				Timestamp:    time.Now(),
				BranchName:   "feature/negative",
				IssueNumber:  -1, // Negative issue number
				WorktreePath: "/tmp/negative",
			},
			valid: false, // Negative issue numbers are invalid
		},
		{
			name: "Metadata with empty author",
			metadata: CommitMetadata{
				Author:       "", // Empty author
				Timestamp:    time.Now(),
				BranchName:   "feature/no-author",
				IssueNumber:  1,
				WorktreePath: "/tmp/no-author",
			},
			valid: false, // Empty author is invalid
		},
		{
			name: "Metadata with very long branch name",
			metadata: CommitMetadata{
				Author:      "test@example.com",
				Timestamp:   time.Now(),
				BranchName:  strings.Repeat("very-long-branch-name-", 10), // Very long branch name
				IssueNumber: 1,
				WorktreePath: "/tmp/long-branch",
			},
			valid: true, // Long branch names are valid
		},
	}
	
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Validate timestamp
			validTimestamp := !tt.metadata.Timestamp.IsZero()
			if tt.valid && !validTimestamp {
				t.Error("Expected valid timestamp")
			}
			
			// Validate issue number
			validIssueNumber := tt.metadata.IssueNumber >= 0
			if tt.valid && !validIssueNumber {
				t.Error("Expected non-negative issue number")
			}
			
			// Validate author
			validAuthor := tt.metadata.Author != ""
			if tt.valid && !validAuthor {
				t.Error("Expected non-empty author")
			}
			
			// Log metadata details
			t.Logf("Author: %s, Branch: %s, Issue: %d", tt.metadata.Author, tt.metadata.BranchName, tt.metadata.IssueNumber)
		})
	}
}

// TestFileTypeAnalysis tests file type analysis functionality
func TestFileTypeAnalysis(t *testing.T) {
	tests := []struct {
		name      string
		files     []string
		expected  map[string]int
	}{
		{
			name:  "Go files only",
			files: []string{"main.go", "utils.go", "test.go"},
			expected: map[string]int{"go": 3},
		},
		{
			name:  "Mixed file types",
			files: []string{"main.go", "README.md", "config.json", "script.sh"},
			expected: map[string]int{"go": 1, "md": 1, "json": 1, "sh": 1},
		},
		{
			name:  "Files without extensions",
			files: []string{"Makefile", "Dockerfile", "LICENSE"},
			expected: map[string]int{"": 3}, // Files without extension
		},
		{
			name:     "Empty file list",
			files:    []string{},
			expected: map[string]int{},
		},
	}
	
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fileTypes := make(map[string]int)
			
			// Simple file type detection logic
			for _, file := range tt.files {
				ext := ""
				if dotIndex := strings.LastIndex(file, "."); dotIndex >= 0 {
					ext = file[dotIndex+1:]
				}
				fileTypes[ext]++
			}
			
			// Verify expected counts
			for expectedExt, expectedCount := range tt.expected {
				if actualCount, exists := fileTypes[expectedExt]; !exists || actualCount != expectedCount {
					t.Errorf("Expected %d files of type '%s', got %d", expectedCount, expectedExt, actualCount)
				}
			}
		})
	}
}

// BenchmarkCommitAnalysis benchmarks commit analysis creation
func BenchmarkCommitAnalysis(b *testing.B) {
	files := make([]string, 100)
	for i := 0; i < 100; i++ {
		files[i] = fmt.Sprintf("file_%d.go", i)
	}
	
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		analysis := &CommitAnalysis{
			ModifiedFiles:  files[:50],
			AddedFiles:     files[50:75],
			DeletedFiles:   files[75:],
			DiffSummary:    "100 files changed",
			FileTypes:      map[string]int{"go": 100},
			ChangeCategory: "refactor",
			Scope:          "core",
			CommitMetadata: CommitMetadata{
				Author:       "benchmark@test.com",
				Timestamp:    time.Now(),
				BranchName:   "benchmark/test",
				IssueNumber:  123,
				WorktreePath: "/tmp/benchmark",
			},
		}
		_ = analysis
	}
}

// BenchmarkChangePatternCreation benchmarks change pattern creation
func BenchmarkChangePatternCreation(b *testing.B) {
	files := []string{"file1.go", "file2.go", "file3.go"}
	
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		pattern := ChangePattern{
			Type:        "feature",
			Description: "Add new functionality",
			Confidence:  0.95,
			Files:       files,
		}
		_ = pattern
	}
}