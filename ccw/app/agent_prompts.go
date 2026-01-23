package app

import (
	"fmt"
	"strings"

	"ccw/git"
	"ccw/types"
)

// Code block delimiters for markdown - can't use backticks inside backtick strings
const (
	codeBlockJSON     = "```json"
	codeBlockMarkdown = "```markdown"
	codeBlockEnd      = "```"
)

// Generate Issue Analysis Prompt for Step 1
func (app *CCWApp) generateIssueAnalysisPrompt(issue *types.Issue, owner, repo string) string {
	var labelsStr string
	if len(issue.Labels) > 0 {
		labelNames := make([]string, len(issue.Labels))
		for i, label := range issue.Labels {
			labelNames[i] = label.Name
		}
		labelsStr = strings.Join(labelNames, ", ")
	} else {
		labelsStr = "none"
	}

	return fmt.Sprintf(`# Issue Analysis Agent

You are a specialized issue analysis agent for the FeLangKit Swift language implementation project.

## Your Task
Analyze the following GitHub issue comprehensively and create an implementation plan.

## Repository Context
- **Project**: %s/%s (Swift Language Implementation)
- **Issue #%d**: %s

## Issue Details
**Description**:
%s

**Labels**: %s
**State**: %s
**Created**: %s

## Analysis Requirements

Please provide a JSON response with the following structure:

%s
{
    "analysis_summary": "Brief summary of what needs to be implemented",
    "complexity_assessment": "simple|moderate|complex",
    "estimated_files_to_change": ["list", "of", "files"],
    "implementation_approach": "Detailed approach description",
    "key_requirements": ["requirement1", "requirement2"],
    "potential_challenges": ["challenge1", "challenge2"],
    "testing_strategy": "How this should be tested",
    "swift_language_impact": "Impact on Swift language features"
}
%s

Focus on:
1. Understanding the Swift language context
2. Identifying affected FeLangCore components
3. Planning minimal, targeted changes
4. Considering test coverage needs

Begin your analysis now.`,
		owner, repo, issue.Number, issue.Title,
		issue.Body,
		labelsStr,
		issue.State,
		issue.CreatedAt.Format("2006-01-02 15:04:05"),
		codeBlockJSON,
		codeBlockEnd)
}

// Generate Implementation Prompt for Step 2
func (app *CCWApp) generateImplementationPrompt(issue *types.Issue, analysis *types.IssueAnalysisResult) string {
	return fmt.Sprintf(`# Implementation Agent

You are an expert Swift language implementation developer working on FeLangKit.

## Project Context
- **Repository**: FeLangKit (Swift Language Implementation)
- **Issue #%d**: %s
- **Working Directory**: %s

## Previous Analysis
%s

## Your Task
Implement the solution based on the analysis above.

## Project Structure
Sources/
├── FeLangCore/          # Core language implementation
│   ├── Expression/      # Expression handling
│   ├── Parser/          # Swift parser
│   ├── Tokenizer/       # Lexical analysis
│   ├── Semantic/        # Semantic analysis
│   └── Utilities/       # Helper utilities
├── FeLangKit/           # Main library interface
├── FeLangRuntime/       # Runtime system
└── FeLangServer/        # Language server protocol

Tests/
├── FeLangCoreTests/     # Core tests
├── FeLangKitTests/      # Library tests
├── FeLangRuntimeTests/  # Runtime tests
└── FeLangServerTests/   # Language server tests

## Implementation Guidelines

1. **Code Quality**:
   - Follow Swift conventions and FeLangKit patterns
   - Add comprehensive documentation
   - Include proper error handling
   - Maintain backward compatibility

2. **Testing**:
   - Add unit tests for new functionality
   - Update existing tests if needed
   - Follow existing test patterns

3. **File Organization**:
   - Follow existing file structure
   - Add new files in appropriate directories
   - Update Package.swift if needed

4. **Swift Language Context**:
   - Consider impact on language features
   - Ensure proper AST handling
   - Maintain parser consistency

## Current Working Directory
You are working in: %s

The project files are already available. Start by examining the existing code structure, then implement the solution.

BEGIN IMPLEMENTATION NOW.`,
		issue.Number, issue.Title, app.worktreeConfig.WorktreePath,
		analysis.ExecutiveSummary,
		app.worktreeConfig.WorktreePath)
}

// Generate Verification Prompt for Step 3
func (app *CCWApp) generateVerificationPrompt(issue *types.Issue, errorStrings []string) string {
	errorsSection := "No validation errors found."
	if len(errorStrings) > 0 {
		errorsSection = fmt.Sprintf("**Validation Errors Found**:\n%s", strings.Join(errorStrings, "\n"))
	}

	return fmt.Sprintf(`# PR Review Agent

You are a code review specialist for the FeLangKit Swift language implementation.

## Issue Context
- **Issue #%d**: %s

## Validation Results
%s

## Your Task
Provide a concise code review focusing on:

1. **Code Quality**: Architecture, patterns, conventions
2. **Swift Language Impact**: How changes affect language features
3. **Test Coverage**: Adequacy of tests for changes
4. **Documentation**: Whether changes are properly documented
5. **Error Handling**: Robustness of error cases

Please provide a brief review in markdown format:

%s
## Code Review Summary

### Overall Assessment
[Brief assessment]

### Strengths
- [Strength 1]
- [Strength 2]

### Areas for Improvement
- [Improvement 1]
- [Improvement 2]

### Swift Language Considerations
[Any language-specific concerns]

### Recommendation
[approve/needs_work/major_changes_needed]
%s

Begin your review now.`,
		issue.Number, issue.Title, errorsSection,
		codeBlockMarkdown, codeBlockEnd)
}

// Generate Fixing Prompt for Step 4
func (app *CCWApp) generateFixingPrompt(issue *types.Issue, verificationResult *git.ValidationResult) string {
	var errorDetails strings.Builder
	errorDetails.WriteString("## Validation Errors to Fix\n\n")

	for _, err := range verificationResult.Errors {
		errorDetails.WriteString(fmt.Sprintf("**%s Error**: %s\n", err.Type, err.Message))
		if err.File != "" {
			errorDetails.WriteString(fmt.Sprintf("  - File: %s", err.File))
			if err.Line > 0 {
				errorDetails.WriteString(fmt.Sprintf(":%d", err.Line))
			}
			errorDetails.WriteString("\n")
		}
		errorDetails.WriteString("\n")
	}

	return fmt.Sprintf(`# Fixing Agent

You are a specialized fixing agent for the FeLangKit Swift language implementation.

## Issue Context
- **Issue #%d**: %s

%s

## Your Task
Fix the validation errors listed above while maintaining the original functionality.

## Fixing Guidelines

1. **Preserve Functionality**: Don't change the core implementation logic
2. **Minimal Changes**: Make the smallest changes needed to fix errors
3. **Follow Patterns**: Use existing FeLangKit code patterns
4. **Test Compatibility**: Ensure fixes don't break existing tests

## Available Tools
- Swift compiler: swift build
- Swift testing: swift test
- Swift linting: swiftlint lint --fix

## Process
1. Analyze each error carefully
2. Identify root cause
3. Implement minimal fix
4. Verify fix doesn't break other functionality

Focus only on fixing the specific errors listed above.

BEGIN FIXING NOW.`,
		issue.Number, issue.Title, errorDetails.String())
}

// Generate Commit Prompt for Step 5
func (app *CCWApp) generateCommitPrompt(issue *types.Issue, analysis *types.IssueAnalysisResult) string {
	return fmt.Sprintf(`# Commit Agent

You are a git commit specialist for the FeLangKit project.

## Issue Context
- **Issue #%d**: %s
- **Analysis Summary**: %s

## Your Task
Generate appropriate commit message(s) for the changes made.

## Commit Message Format
Use conventional commits format:

<type>(<scope>): <description>

<body>

Refs #<issue_number>

## Guidelines
1. **Type**: feat, fix, docs, style, refactor, test, chore
2. **Scope**: parser, tokenizer, semantic, runtime, server, core
3. **Description**: Concise summary (≤50 chars)
4. **Body**: Detailed explanation if needed
5. **Reference**: Always include "Refs #%d"

## Multiple Commits
If changes are substantial, suggest multiple small commits:
- One commit per logical change
- Each commit should be atomic and buildable
- Clear progression from simple to complex changes

Please analyze the current changes and provide commit message(s):

%s
{
    "commit_messages": [
        {
            "message": "feat(parser): add support for new syntax\n\nImplement parsing logic for enhanced expressions\nas requested in issue requirements.\n\nRefs #%d",
            "files_included": "Brief description of what files this commit should include"
        }
    ]
}
%s

Begin commit message generation now.`,
		issue.Number, issue.Title, analysis.ExecutiveSummary, issue.Number,
		codeBlockJSON, issue.Number, codeBlockEnd)
}

// Generate PR Description Prompt for Step 6
func (app *CCWApp) generatePRDescriptionPrompt(issue *types.Issue, analysis *types.IssueAnalysisResult) string {
	return fmt.Sprintf(`# PR Description Agent

You are a PR description specialist for the FeLangKit Swift language implementation.

## Issue Context
- **Issue #%d**: %s
- **Analysis**: %s

## Your Task
Generate a comprehensive PR title and description.

## PR Title Format
"Resolve #%d: <clear, concise description>"

## PR Description Format
%s
## Summary
Brief one-line summary of changes

## Context
Why this change was needed (reference to issue)

## Changes Made
- Change 1
- Change 2
- Change 3

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests pass
- [ ] Manual testing performed

## Swift Language Impact
Description of any language feature impacts

## Checklist
- [ ] Code follows FeLangKit conventions
- [ ] Documentation updated
- [ ] Tests added for new functionality
- [ ] No breaking changes (or clearly documented)

## Related
Closes #%d

---
Generated with Claude Code Workflow
%s

Please provide the PR title and description:

%s
{
    "title": "Resolve #%d: <title>",
    "description": "<full markdown description>"
}
%s

Begin PR description generation now.`,
		issue.Number, issue.Title, analysis.ExecutiveSummary,
		issue.Number,
		codeBlockMarkdown, issue.Number, codeBlockEnd,
		codeBlockJSON, issue.Number, codeBlockEnd)
}

// Generate CI Fixing Prompt for Step 8
func (app *CCWApp) generateCIFixingPrompt(issue *types.Issue, failures []types.CIFailureInfo) string {
	var failureDetails strings.Builder
	failureDetails.WriteString("## CI Failures to Fix\n\n")

	for _, failure := range failures {
		failureDetails.WriteString(fmt.Sprintf("**%s Failure**: %s\n", failure.Type, failure.CheckName))
		if failure.FailureText != "" {
			failureDetails.WriteString(fmt.Sprintf("Details: %s\n", failure.FailureText))
		}
		if failure.DetailsURL != "" {
			failureDetails.WriteString(fmt.Sprintf("URL: %s\n", failure.DetailsURL))
		}
		failureDetails.WriteString(fmt.Sprintf("Recoverable: %t\n\n", failure.Recoverable))
	}

	return fmt.Sprintf(`# CI Fixing Agent

You are a CI/CD fixing specialist for the FeLangKit Swift language implementation.

## Issue Context
- **Issue #%d**: %s

%s

## Your Task
Fix the CI failures listed above with minimal, targeted changes.

## Fixing Strategy
1. **Build Failures**: Check dependencies, imports, API changes
2. **Test Failures**: Update tests to match new functionality
3. **Lint Failures**: Run swiftlint lint --fix and address remaining issues
4. **Unknown Failures**: Investigate logs and apply appropriate fixes

## Guidelines
- Focus only on fixing CI failures
- Preserve existing functionality
- Follow project conventions
- Add minimal, targeted fixes
- Document any significant changes in commit message

Begin fixing the CI failures systematically now.`,
		issue.Number, issue.Title, failureDetails.String())
}
