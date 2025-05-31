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
	Mutex               sync.RWMutex
}

type ChangeDetector struct {
	LastContent   string
	LastHash      string
	ChangeHistory []time.Time
	Sensitivity   float64
	MinInterval   time.Duration
	Mutex         sync.RWMutex
}

type AdaptiveRefreshController struct {
	CurrentInterval   time.Duration
	MinInterval       time.Duration
	MaxInterval       time.Duration
	ChangeVelocity    float64
	LastAdjustment    time.Time
	AdjustmentHistory []time.Duration
	OptimizationLevel int
	Mutex             sync.RWMutex
}

type ContentCache struct {
	Cache       map[string]CachedContent
	MaxSize     int
	TTL         time.Duration
	HitCount    int
	MissCount   int
	Mutex       sync.RWMutex
	LastCleanup time.Time
}

type CachedContent struct {
	Content     string
	Hash        string
	Timestamp   time.Time
	AccessCount int
	LastAccess  time.Time
	Size        int
}

type PerformanceOptimizer struct {
	Config                    *PerformanceConfig
	ChangeDetector            *ChangeDetector
	AdaptiveController        *AdaptiveRefreshController
	ContentCache              *ContentCache
	Metrics                   *PerformanceMetrics
	Mutex                     sync.RWMutex
	IsOptimizationEnabled     bool
	LastOptimizationCheck     time.Time
	OptimizationCheckInterval time.Duration
}

// PerformanceOptimizer implementation functions

// NewPerformanceOptimizer creates a new performance optimizer
func NewPerformanceOptimizer(config *PerformanceConfig) *PerformanceOptimizer {
	return &PerformanceOptimizer{
		Config: config,
		ChangeDetector: &ChangeDetector{
			Sensitivity:   config.ChangeDetectionSensitivity,
			MinInterval:   config.MinRefreshInterval,
			ChangeHistory: make([]time.Time, 0),
		},
		AdaptiveController: &AdaptiveRefreshController{
			CurrentInterval:   config.MinRefreshInterval,
			MinInterval:       config.MinRefreshInterval,
			MaxInterval:       config.MaxRefreshInterval,
			OptimizationLevel: config.OptimizationLevel,
			AdjustmentHistory: make([]time.Duration, 0),
		},
		ContentCache: &ContentCache{
			Cache:   make(map[string]CachedContent),
			MaxSize: config.CacheSize,
			TTL:     config.CacheTTL,
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
		IsOptimizationEnabled:     config.EnableAdaptiveRefresh,
		OptimizationCheckInterval: 10 * time.Second,
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
	po.Mutex.RLock()
	defer po.Mutex.RUnlock()

	if po.AdaptiveController != nil {
		return po.AdaptiveController.CurrentInterval
	}
	return po.Config.MinRefreshInterval
}

func (po *PerformanceOptimizer) GetPerformanceStats() *PerformanceMetrics {
	po.Mutex.RLock()
	defer po.Mutex.RUnlock()
	return po.Metrics
}

func (po *PerformanceOptimizer) DetectContentChange(content string) (bool, float64) {
	po.Mutex.Lock()
	defer po.Mutex.Unlock()

	if po.ChangeDetector == nil {
		return true, 1.0 // Always update if no detector
	}

	// Simple change detection based on content hash
	currentHash := po.calculateContentHash(content)
	hasChanged := currentHash != po.ChangeDetector.LastHash

	if hasChanged {
		po.ChangeDetector.LastContent = content
		po.ChangeDetector.LastHash = currentHash
		po.ChangeDetector.ChangeHistory = append(po.ChangeDetector.ChangeHistory, time.Now())

		// Keep only recent changes (last 10 seconds)
		cutoff := time.Now().Add(-10 * time.Second)
		filtered := make([]time.Time, 0)
		for _, t := range po.ChangeDetector.ChangeHistory {
			if t.After(cutoff) {
				filtered = append(filtered, t)
			}
		}
		po.ChangeDetector.ChangeHistory = filtered

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
	po.Mutex.RLock()
	defer po.Mutex.RUnlock()

	// Create a copy to avoid race conditions
	metricsCopy := *po.Metrics
	return &metricsCopy
}

// String returns a formatted string representation of PerformanceMetrics
func (pm *PerformanceMetrics) String() string {
	pm.Mutex.RLock()
	defer pm.Mutex.RUnlock()

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
