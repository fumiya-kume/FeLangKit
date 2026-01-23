package performance

import (
	"ccw/types"
)

// Performance optimization and monitoring
// This package provides a facade over the types.PerformanceOptimizer

// Create new performance optimizer
func NewPerformanceOptimizer(config *types.PerformanceConfig) *types.PerformanceOptimizer {
	return types.NewPerformanceOptimizer(config)
}

// Get default performance configuration
func GetDefaultPerformanceConfig() *types.PerformanceConfig {
	return types.GetDefaultPerformanceConfig()
}
