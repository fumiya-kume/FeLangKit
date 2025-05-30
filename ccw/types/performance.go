package types

import (
	"fmt"
	"sync"
	"time"
)

// Performance optimization models

type PerformanceConfig struct {
	EnableAdaptiveRefresh      bool
	EnableContentCaching       bool
	EnableSelectiveUpdates     bool
	MinRefreshInterval         time.Duration
	MaxRefreshInterval         time.Duration
	CacheSize                  int
	CacheTTL                   time.Duration
	OptimizationLevel          int
	DebounceThreshold          time.Duration
	ChangeDetectionSensitivity float64
}

type PerformanceMetrics struct {
	TotalRenders        int
	SkippedRenders      int
	AverageRenderTime   time.Duration
	MaxRenderTime       time.Duration
	MinRenderTime       time.Duration
	ContentChangeRate   float64
	OptimizationLevel   int
	AdaptiveAdjustments int
	mutex               sync.RWMutex
}

type ChangeDetector struct {
	lastContent   string
	lastHash      string
	changeHistory []time.Time
	sensitivity   float64
	minInterval   time.Duration
	mutex         sync.RWMutex
}

type AdaptiveRefreshController struct {
	currentInterval   time.Duration
	minInterval       time.Duration
	maxInterval       time.Duration
	changeVelocity    float64
	lastAdjustment    time.Time
	adjustmentHistory []time.Duration
	optimizationLevel int
	mutex             sync.RWMutex
}

type ContentCache struct {
	cache       map[string]CachedContent
	maxSize     int
	ttl         time.Duration
	hitCount    int
	missCount   int
	mutex       sync.RWMutex
	lastCleanup time.Time
}

type CachedContent struct {
	content     string
	hash        string
	timestamp   time.Time
	accessCount int
	lastAccess  time.Time
	size        int
}

type PerformanceOptimizer struct {
	config                    *PerformanceConfig
	changeDetector            *ChangeDetector
	adaptiveController        *AdaptiveRefreshController
	contentCache              *ContentCache
	Metrics                   *PerformanceMetrics
	mutex                     sync.RWMutex
	isOptimizationEnabled     bool
	lastOptimizationCheck     time.Time
	optimizationCheckInterval time.Duration
}

// PerformanceOptimizer implementation functions

// NewPerformanceOptimizer creates a new performance optimizer
func NewPerformanceOptimizer(config *PerformanceConfig) *PerformanceOptimizer {
	return &PerformanceOptimizer{
		config: config,
		changeDetector: &ChangeDetector{
			sensitivity:   config.ChangeDetectionSensitivity,
			minInterval:   config.MinRefreshInterval,
			changeHistory: make([]time.Time, 0),
		},
		adaptiveController: &AdaptiveRefreshController{
			currentInterval:   config.MinRefreshInterval,
			minInterval:       config.MinRefreshInterval,
			maxInterval:       config.MaxRefreshInterval,
			optimizationLevel: config.OptimizationLevel,
			adjustmentHistory: make([]time.Duration, 0),
		},
		contentCache: &ContentCache{
			cache:   make(map[string]CachedContent),
			maxSize: config.CacheSize,
			ttl:     config.CacheTTL,
		},
		Metrics: &PerformanceMetrics{
			TotalRenders:      0,
			SkippedRenders:    0,
			AverageRenderTime: 0,
			MaxRenderTime:     0,
			MinRenderTime:     time.Hour, // Start with high value
			ContentChangeRate: 0,
			OptimizationLevel: config.OptimizationLevel,
		},
		isOptimizationEnabled:     config.EnableAdaptiveRefresh,
		optimizationCheckInterval: 10 * time.Second,
	}
}

// GetDefaultPerformanceConfig returns default performance configuration
func GetDefaultPerformanceConfig() *PerformanceConfig {
	return &PerformanceConfig{
		EnableAdaptiveRefresh:      true,
		EnableContentCaching:       true,
		EnableSelectiveUpdates:     true,
		MinRefreshInterval:         100 * time.Millisecond,
		MaxRefreshInterval:         1 * time.Second,
		CacheSize:                  100,
		CacheTTL:                   5 * time.Minute,
		OptimizationLevel:          2,
		DebounceThreshold:          50 * time.Millisecond,
		ChangeDetectionSensitivity: 0.1,
	}
}

// Performance optimizer methods
func (po *PerformanceOptimizer) GetOptimalRefreshInterval() time.Duration {
	po.mutex.RLock()
	defer po.mutex.RUnlock()

	if po.adaptiveController != nil {
		return po.adaptiveController.currentInterval
	}
	return po.config.MinRefreshInterval
}

func (po *PerformanceOptimizer) GetPerformanceStats() *PerformanceMetrics {
	po.mutex.RLock()
	defer po.mutex.RUnlock()
	return po.Metrics
}

func (po *PerformanceOptimizer) DetectContentChange(content string) (bool, float64) {
	po.mutex.Lock()
	defer po.mutex.Unlock()

	if po.changeDetector == nil {
		return true, 1.0 // Always update if no detector
	}

	// Simple change detection based on content hash
	currentHash := po.calculateContentHash(content)
	hasChanged := currentHash != po.changeDetector.lastHash

	if hasChanged {
		po.changeDetector.lastContent = content
		po.changeDetector.lastHash = currentHash
		po.changeDetector.changeHistory = append(po.changeDetector.changeHistory, time.Now())

		// Keep only recent changes (last 10 seconds)
		cutoff := time.Now().Add(-10 * time.Second)
		filtered := make([]time.Time, 0)
		for _, t := range po.changeDetector.changeHistory {
			if t.After(cutoff) {
				filtered = append(filtered, t)
			}
		}
		po.changeDetector.changeHistory = filtered

		return true, 1.0
	}

	return false, 0.0
}

func (po *PerformanceOptimizer) calculateContentHash(content string) string {
	// Simple hash based on content length and first/last chars
	if len(content) == 0 {
		return "empty"
	}
	return fmt.Sprintf("%d-%c-%c", len(content), content[0], content[len(content)-1])
}

// AccessibleMetrics returns publicly accessible metrics
func (po *PerformanceOptimizer) AccessibleMetrics() *PerformanceMetrics {
	po.mutex.RLock()
	defer po.mutex.RUnlock()

	// Create a copy to avoid race conditions
	metricsCopy := *po.Metrics
	return &metricsCopy
}

// String returns a formatted string representation of PerformanceMetrics
func (pm *PerformanceMetrics) String() string {
	pm.mutex.RLock()
	defer pm.mutex.RUnlock()

	// Handle the case where MinRenderTime is uninitialized (1 hour default)
	minRenderTime := pm.MinRenderTime
	if minRenderTime >= time.Hour {
		minRenderTime = 0 // Show 0 if no renders have occurred
	}

	return fmt.Sprintf("PerformanceStats{TotalRenders:%d, SkippedRenders:%d, AvgRenderTime:%s, MaxRenderTime:%s, MinRenderTime:%s, ChangeRate:%.2f, OptLevel:%d, Adjustments:%d}",
		pm.TotalRenders,
		pm.SkippedRenders,
		pm.AverageRenderTime,
		pm.MaxRenderTime,
		minRenderTime,
		pm.ContentChangeRate,
		pm.OptimizationLevel,
		pm.AdaptiveAdjustments,
	)
}
