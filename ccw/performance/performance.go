package performance

import (
	"crypto/sha256"
	"fmt"
	"time"
)

// Performance optimization and monitoring

// Create new performance optimizer
func NewPerformanceOptimizer(config *PerformanceConfig) *PerformanceOptimizer {
	po := &PerformanceOptimizer{
		config:                    config,
		isOptimizationEnabled:     true,
		optimizationCheckInterval: 5 * time.Second,
		lastOptimizationCheck:     time.Now(),
	}

	// Initialize components
	po.changeDetector = &ChangeDetector{
		sensitivity: config.ChangeDetectionSensitivity,
		minInterval: config.MinRefreshInterval,
	}

	po.adaptiveController = &AdaptiveRefreshController{
		currentInterval:   config.MinRefreshInterval,
		minInterval:       config.MinRefreshInterval,
		maxInterval:       config.MaxRefreshInterval,
		optimizationLevel: config.OptimizationLevel,
	}

	po.contentCache = &ContentCache{
		cache:   make(map[string]CachedContent),
		maxSize: config.CacheSize,
		ttl:     config.CacheTTL,
	}

	po.metrics = &PerformanceMetrics{
		MinRenderTime: time.Hour, // Initialize to high value
	}

	return po
}

// Get default performance configuration
func getDefaultPerformanceConfig() *PerformanceConfig {
	return &PerformanceConfig{
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

// Detect content changes with sophisticated algorithms
func (po *PerformanceOptimizer) DetectContentChange(content string) (bool, float64) {
	po.mutex.Lock()
	defer po.mutex.Unlock()

	// Quick hash comparison for exact matches
	currentHash := po.calculateContentHash(content)
	if po.changeDetector.lastHash == currentHash {
		return false, 0.0
	}

	// Calculate change magnitude using sophisticated algorithms
	changeMagnitude := po.calculateChangeMagnitude(po.changeDetector.lastContent, content)

	// Update change detector state
	po.changeDetector.lastContent = content
	po.changeDetector.lastHash = currentHash
	po.changeDetector.changeHistory = append(po.changeDetector.changeHistory, time.Now())

	// Cleanup old history (keep last 10 entries)
	if len(po.changeDetector.changeHistory) > 10 {
		po.changeDetector.changeHistory = po.changeDetector.changeHistory[len(po.changeDetector.changeHistory)-10:]
	}

	// Update metrics
	po.metrics.ContentChangeRate = po.calculateChangeRate()

	return changeMagnitude > po.changeDetector.sensitivity, changeMagnitude
}

// Calculate content hash using SHA256
func (po *PerformanceOptimizer) calculateContentHash(content string) string {
	hasher := sha256.New()
	hasher.Write([]byte(content))
	return fmt.Sprintf("%x", hasher.Sum(nil))[:16] // Use first 16 chars for performance
}

// Calculate change magnitude using multiple algorithms
func (po *PerformanceOptimizer) calculateChangeMagnitude(oldContent, newContent string) float64 {
	if oldContent == "" {
		return 1.0 // Complete change if no previous content
	}

	if oldContent == newContent {
		return 0.0 // No change
	}

	// Use Jaro-Winkler inspired similarity for short content
	if len(oldContent) < 1000 && len(newContent) < 1000 {
		return 1.0 - po.calculateJaroWinklerSimilarity(oldContent, newContent)
	}

	// Use sample-based similarity for longer content
	return 1.0 - po.calculateSampleBasedSimilarity(oldContent, newContent)
}

// Calculate Jaro-Winkler similarity (simplified implementation)
func (po *PerformanceOptimizer) calculateJaroWinklerSimilarity(s1, s2 string) float64 {
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
func (po *PerformanceOptimizer) calculateSampleBasedSimilarity(s1, s2 string) float64 {
	sampleSize := 100
	samples := 5

	if len(s1) < sampleSize || len(s2) < sampleSize {
		return po.calculateSimpleEditDistance(s1, s2)
	}

	totalSimilarity := 0.0

	for i := 0; i < samples; i++ {
		offset1 := (len(s1) * i) / samples
		offset2 := (len(s2) * i) / samples

		end1 := minInt(offset1+sampleSize, len(s1))
		end2 := minInt(offset2+sampleSize, len(s2))

		sample1 := s1[offset1:end1]
		sample2 := s2[offset2:end2]

		similarity := po.calculateSimpleEditDistance(sample1, sample2)
		totalSimilarity += similarity
	}

	return totalSimilarity / float64(samples)
}

// Calculate simple edit distance based similarity
func (po *PerformanceOptimizer) calculateSimpleEditDistance(s1, s2 string) float64 {
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

// Calculate change rate based on history
func (po *PerformanceOptimizer) calculateChangeRate() float64 {
	if len(po.changeDetector.changeHistory) < 2 {
		return 0.0
	}

	recentChanges := po.changeDetector.changeHistory
	timeSpan := recentChanges[len(recentChanges)-1].Sub(recentChanges[0])

	if timeSpan == 0 {
		return 0.0
	}

	return float64(len(recentChanges)) / timeSpan.Seconds()
}

// Get optimal refresh interval based on performance metrics
func (po *PerformanceOptimizer) GetOptimalRefreshInterval() time.Duration {
	po.mutex.RLock()
	defer po.mutex.RUnlock()

	// Base interval on change rate and performance
	changeRate := po.metrics.ContentChangeRate
	skipRatio := float64(po.metrics.SkippedRenders) / float64(maxInt(po.metrics.TotalRenders, 1))

	// Adjust interval based on skip ratio
	if skipRatio > 0.8 {
		// Too many skips, reduce frequency
		return po.adaptiveController.maxInterval
	} else if skipRatio < 0.2 && changeRate > 0.5 {
		// High change rate, increase frequency
		return po.adaptiveController.minInterval
	}

	// Use current interval with small adjustments
	currentInterval := po.adaptiveController.currentInterval

	if changeRate > 1.0 {
		currentInterval = time.Duration(float64(currentInterval) * 0.9)
	} else if changeRate < 0.1 {
		currentInterval = time.Duration(float64(currentInterval) * 1.1)
	}

	// Ensure within bounds
	if currentInterval < po.adaptiveController.minInterval {
		currentInterval = po.adaptiveController.minInterval
	}
	if currentInterval > po.adaptiveController.maxInterval {
		currentInterval = po.adaptiveController.maxInterval
	}

	po.adaptiveController.currentInterval = currentInterval
	return currentInterval
}

// Get performance statistics
func (po *PerformanceOptimizer) GetPerformanceStats() map[string]interface{} {
	po.mutex.RLock()
	defer po.mutex.RUnlock()

	cacheHitRate := 0.0
	if po.contentCache.hitCount+po.contentCache.missCount > 0 {
		cacheHitRate = float64(po.contentCache.hitCount) / float64(po.contentCache.hitCount+po.contentCache.missCount)
	}

	return map[string]interface{}{
		"total_renders":       po.metrics.TotalRenders,
		"skipped_renders":     po.metrics.SkippedRenders,
		"avg_render_time":     po.metrics.AverageRenderTime,
		"content_change_rate": po.metrics.ContentChangeRate,
		"cache_hit_rate":      cacheHitRate,
		"current_interval":    po.adaptiveController.currentInterval,
		"optimization_level":  po.metrics.OptimizationLevel,
	}
}

// Update performance metrics
func (po *PerformanceOptimizer) UpdateMetrics(renderTime time.Duration, wasSkipped bool) {
	po.metrics.mutex.Lock()
	defer po.metrics.mutex.Unlock()

	po.metrics.TotalRenders++

	if wasSkipped {
		po.metrics.SkippedRenders++
	} else {
		// Update render time statistics
		if renderTime > po.metrics.MaxRenderTime {
			po.metrics.MaxRenderTime = renderTime
		}
		if renderTime < po.metrics.MinRenderTime {
			po.metrics.MinRenderTime = renderTime
		}

		// Update average (simple moving average)
		if po.metrics.AverageRenderTime == 0 {
			po.metrics.AverageRenderTime = renderTime
		} else {
			po.metrics.AverageRenderTime = (po.metrics.AverageRenderTime + renderTime) / 2
		}
	}
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
