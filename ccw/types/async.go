package types

// Async result types for non-blocking operations

// ResultChannel provides type-safe channel for async operations
type ResultChannel[T any] struct {
	Channel <-chan T
}

// PRDescriptionResult contains the result of async PR description generation
type PRDescriptionResult struct {
	Description string
	Error       error
}

// ImplementationSummaryResult contains the result of async implementation summary generation
type ImplementationSummaryResult struct {
	Summary string
	Error   error
}

// AnalysisResult contains the result of async code analysis
type AnalysisResult struct {
	Analysis string
	Error    error
}

// PRResult contains the result of async PR creation
type PRResult struct {
	PullRequest *PullRequest
	Error       error
}

// CIStatusResult contains the result of async CI status monitoring
type CIStatusResult struct {
	Status *CIStatus
	Error  error
}