package ui

import (
	"fmt"
	"strconv"
	"strings"
)

// isLightColor determines if a color is light or dark
func isLightColor(colorHex string) bool {
	// Remove # if present
	colorHex = strings.TrimPrefix(colorHex, "#")

	// Parse RGB values
	if len(colorHex) != 6 {
		return false
	}

	r, err1 := strconv.ParseInt(colorHex[0:2], 16, 0)
	g, err2 := strconv.ParseInt(colorHex[2:4], 16, 0)
	b, err3 := strconv.ParseInt(colorHex[4:6], 16, 0)

	if err1 != nil || err2 != nil || err3 != nil {
		return false
	}

	// Calculate perceived brightness using standard formula
	brightness := (0.299*float64(r) + 0.587*float64(g) + 0.114*float64(b)) / 255.0
	return brightness > 0.5
}

// darkenColor darkens a hex color by a given factor (0.0 to 1.0)
func darkenColor(colorHex string, factor float64) string {
	colorHex = strings.TrimPrefix(colorHex, "#")

	if len(colorHex) != 6 {
		return colorHex // Return original if invalid
	}

	r, err1 := strconv.ParseInt(colorHex[0:2], 16, 0)
	g, err2 := strconv.ParseInt(colorHex[2:4], 16, 0)
	b, err3 := strconv.ParseInt(colorHex[4:6], 16, 0)

	if err1 != nil || err2 != nil || err3 != nil {
		return colorHex // Return original if parse fails
	}

	// Darken by reducing each component
	r = int64(float64(r) * (1.0 - factor))
	g = int64(float64(g) * (1.0 - factor))
	b = int64(float64(b) * (1.0 - factor))

	// Ensure values stay in valid range
	if r < 0 {
		r = 0
	}
	if g < 0 {
		g = 0
	}
	if b < 0 {
		b = 0
	}
	if r > 255 {
		r = 255
	}
	if g > 255 {
		g = 255
	}
	if b > 255 {
		b = 255
	}

	return fmt.Sprintf("#%02X%02X%02X", r, g, b)
}