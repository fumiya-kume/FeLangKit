package app

import (
	"ccw/git"
	"ccw/types"
)

// ConvertValidationResult converts git.ValidationResult to types.ValidationResult
func ConvertValidationResult(gitResult *git.ValidationResult) *types.ValidationResult {
	if gitResult == nil {
		return nil
	}
	
	return &types.ValidationResult{
		Success:     gitResult.Success,
		LintResult:  convertLintResult(gitResult.LintResult),
		BuildResult: convertBuildResult(gitResult.BuildResult),
		TestResult:  convertTestResult(gitResult.TestResult),
		Errors:      convertValidationErrors(gitResult.Errors),
		Duration:    gitResult.Duration,
		Timestamp:   gitResult.Timestamp,
	}
}

// convertLintResult converts git.LintResult to types.LintResult
func convertLintResult(gitResult *git.LintResult) *types.LintResult {
	if gitResult == nil {
		return nil
	}
	return &types.LintResult{
		Success:   gitResult.Success,
		Output:    gitResult.Output,
		Errors:    gitResult.Errors,
		Warnings:  gitResult.Warnings,
		AutoFixed: gitResult.AutoFixed,
	}
}

// convertBuildResult converts git.BuildResult to types.BuildResult
func convertBuildResult(gitResult *git.BuildResult) *types.BuildResult {
	if gitResult == nil {
		return nil
	}
	return &types.BuildResult{
		Success: gitResult.Success,
		Output:  gitResult.Output,
		Error:   gitResult.Error,
	}
}

// convertTestResult converts git.TestResult to types.TestResult
func convertTestResult(gitResult *git.TestResult) *types.TestResult {
	if gitResult == nil {
		return nil
	}
	return &types.TestResult{
		Success:   gitResult.Success,
		Output:    gitResult.Output,
		TestCount: gitResult.TestCount,
		Passed:    gitResult.Passed,
		Failed:    gitResult.Failed,
	}
}

// convertValidationErrors converts git.ValidationError slice to types.ValidationError slice
func convertValidationErrors(gitErrors []git.ValidationError) []types.ValidationError {
	if gitErrors == nil {
		return nil
	}
	
	typesErrors := make([]types.ValidationError, len(gitErrors))
	for i, gitError := range gitErrors {
		typesErrors[i] = types.ValidationError{
			Type:        gitError.Type,
			Message:     gitError.Message,
			File:        gitError.File,
			Line:        gitError.Line,
			Recoverable: gitError.Recoverable,
		}
	}
	return typesErrors
}