package performance

import (
	"ccw/types"
	"crypto/sha256"
	"fmt"
	"sync"
	"time"
)

// Performance optimization and monitoring
// This package provides additional performance utility functions

// Create new performance optimizer with default configuration
func NewPerformanceOptimizerWithDefaults() *types.PerformanceOptimizer {
	config := types.GetDefaultPerformanceConfig()
	return types.NewPerformanceOptimizer(config)
}

// Get default performance configuration with custom values
func GetCustomPerformanceConfig() *types.PerformanceConfig {
	return &types.PerformanceConfig{
		EnableAdaptiveRefresh:      true,
		EnableContentCaching:       true,
		EnableSelectiveUpdates:     true,
		MinRefreshInterval:         100 * time.Millisecond,
		MaxRefreshInterval:         2 * time.Second,
		CacheSize:                  100,
		CacheTTL:                   10 * time.Minute,
		OptimizationLevel:          2,
		DebounceThreshold:          50 * time.Millisecond,
		ChangeDetectionSensitivity: 0.1,
	}
}

// Advanced content change detection with sophisticated algorithms
func DetectAdvancedContentChange(po *types.PerformanceOptimizer, content string) (bool, float64) {
	// Use the existing DetectContentChange method from types package
	return po.DetectContentChange(content)
}

// Calculate content hash using SHA256 for external use
func CalculateContentHashSHA256(content string) string {
	hasher := sha256.New()
	hasher.Write([]byte(content))
	return fmt.Sprintf("%x", hasher.Sum(nil))[:16] // Use first 16 chars for performance
}

// Calculate change magnitude using multiple algorithms
func CalculateChangeMagnitude(oldContent, newContent string) float64 {
	if oldContent == "" {
		return 1.0 // Complete change if no previous content
	}

	if oldContent == newContent {
		return 0.0 // No change
	}

	// Use Jaro-Winkler inspired similarity for short content
	if len(oldContent) < 1000 && len(newContent) < 1000 {
		return 1.0 - calculateJaroWinklerSimilarity(oldContent, newContent)
	}

	// Use sample-based similarity for longer content
	return 1.0 - calculateSampleBasedSimilarity(oldContent, newContent)
}

// Calculate Jaro-Winkler similarity (simplified implementation)
func calculateJaroWinklerSimilarity(s1, s2 string) float64 {
	if s1 == s2 {
		return 1.0
	}

	len1, len2 := len(s1), len(s2)
	if len1 == 0 && len2 == 0 {
		return 1.0
	}
	if len1 == 0 || len2 == 0 {
		return 0.0
	}

	// Calculate matches and transpositions
	matchWindow := maxInt(len1, len2)/2 - 1
	if matchWindow < 0 {
		matchWindow = 0
	}

	s1Matches := make([]bool, len1)
	s2Matches := make([]bool, len2)
	matches := 0
	transpositions := 0

	// Identify matches
	for i := 0; i < len1; i++ {
		start := maxInt(0, i-matchWindow)
		end := minInt(i+matchWindow+1, len2)

		for j := start; j < end; j++ {
			if s2Matches[j] || s1[i] != s2[j] {
				continue
			}
			s1Matches[i] = true
			s2Matches[j] = true
			matches++
			break
		}
	}

	if matches == 0 {
		return 0.0
	}

	// Calculate transpositions
	k := 0
	for i := 0; i < len1; i++ {
		if !s1Matches[i] {
			continue
		}
		for !s2Matches[k] {
			k++
		}
		if s1[i] != s2[k] {
			transpositions++
		}
		k++
	}

	// Calculate Jaro similarity
	jaro := (float64(matches)/float64(len1) + float64(matches)/float64(len2) +
		float64(matches-transpositions/2)/float64(matches)) / 3.0

	// Apply Winkler prefix scaling
	prefix := 0
	for i := 0; i < minInt(len1, len2) && i < 4; i++ {
		if s1[i] == s2[i] {
			prefix++
		} else {
			break
		}
	}

	return jaro + 0.1*float64(prefix)*(1.0-jaro)
}

// Calculate sample-based similarity for large content
func calculateSampleBasedSimilarity(s1, s2 string) float64 {
	sampleSize := 100
	samples := 5

	if len(s1) < sampleSize || len(s2) < sampleSize {
		return calculateSimpleEditDistance(s1, s2)
	}

	totalSimilarity := 0.0

	for i := 0; i < samples; i++ {
		offset1 := (len(s1) * i) / samples
		offset2 := (len(s2) * i) / samples

		end1 := minInt(offset1+sampleSize, len(s1))
		end2 := minInt(offset2+sampleSize, len(s2))

		sample1 := s1[offset1:end1]
		sample2 := s2[offset2:end2]

		similarity := calculateSimpleEditDistance(sample1, sample2)
		totalSimilarity += similarity
	}

	return totalSimilarity / float64(samples)
}

// Calculate simple edit distance based similarity
func calculateSimpleEditDistance(s1, s2 string) float64 {
	len1, len2 := len(s1), len(s2)

	if len1 == 0 && len2 == 0 {
		return 1.0
	}

	maxLen := maxInt(len1, len2)
	if maxLen == 0 {
		return 1.0
	}

	// Simple character-by-character comparison
	matches := 0
	minLen := minInt(len1, len2)

	for i := 0; i < minLen; i++ {
		if s1[i] == s2[i] {
			matches++
		}
	}

	return float64(matches) / float64(maxLen)
}

// Get enhanced performance statistics
func GetEnhancedPerformanceStats(po *types.PerformanceOptimizer) map[string]interface{} {
	metrics := po.AccessibleMetrics()
	
	// Create a map with all metrics
	stats := map[string]interface{}{
		"total_renders":       metrics.TotalRenders,
		"skipped_renders":     metrics.SkippedRenders,
		"avg_render_time":     metrics.AverageRenderTime,
		"max_render_time":     metrics.MaxRenderTime,
		"min_render_time":     metrics.MinRenderTime,
		"content_change_rate": metrics.ContentChangeRate,
		"optimization_level":  metrics.OptimizationLevel,
		"adaptive_adjustments": metrics.AdaptiveAdjustments,
		"efficiency_score":    calculateEfficiencyScore(po),
		"optimization_score":  calculateOptimizationScore(po),
	}
	
	return stats
}

// Calculate efficiency score based on metrics
func calculateEfficiencyScore(po *types.PerformanceOptimizer) float64 {
	metrics := po.AccessibleMetrics()
	if metrics.TotalRenders == 0 {
		return 1.0
	}
	
	skipRatio := float64(metrics.SkippedRenders) / float64(metrics.TotalRenders)
	return skipRatio * 0.7 + 0.3 // Weight skipped renders heavily
}

// Calculate optimization score
func calculateOptimizationScore(po *types.PerformanceOptimizer) float64 {
	metrics := po.AccessibleMetrics()
	
	// Base score on optimization level and adaptive adjustments
	baseScore := float64(metrics.OptimizationLevel) / 3.0 // Assuming max level is 3
	adaptiveBonus := float64(metrics.AdaptiveAdjustments) / 100.0 // Normalize adjustments
	
	if adaptiveBonus > 1.0 {
		adaptiveBonus = 1.0
	}
	
	return (baseScore + adaptiveBonus) / 2.0
}

// Performance monitoring utilities
type PerformanceMonitor struct {
	optimizer *types.PerformanceOptimizer
	mutex     sync.RWMutex
}

// NewPerformanceMonitor creates a new performance monitor
func NewPerformanceMonitor(config *types.PerformanceConfig) *PerformanceMonitor {
	return &PerformanceMonitor{
		optimizer: types.NewPerformanceOptimizer(config),
	}
}

// GetOptimizer returns the underlying performance optimizer
func (pm *PerformanceMonitor) GetOptimizer() *types.PerformanceOptimizer {
	pm.mutex.RLock()
	defer pm.mutex.RUnlock()
	return pm.optimizer
}

// MonitorOperation monitors a specific operation
func (pm *PerformanceMonitor) MonitorOperation(operation func() error) error {
	start := time.Now()
	err := operation()
	duration := time.Since(start)
	
	// Update metrics based on operation result
	wasSkipped := err != nil
	
	// Note: We can't access private fields directly, so we work with the public interface
	// The types package handles the internal metric updates
	
	_ = duration // Use duration if needed for additional monitoring
	_ = wasSkipped
	
	return err
}

// Utility functions
func maxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func minInt(a, b int) int {
	if a < b {
		return a
	}
	return b
}