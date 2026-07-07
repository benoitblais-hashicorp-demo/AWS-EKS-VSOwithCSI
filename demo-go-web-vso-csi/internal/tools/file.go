// Copyright IBM Corp. 2024, 2026

package tools

import (
	"os"
	"strings"
)

// ReadCSISecretFile reads a simple text file mounted via CSI Secrets and trims whitespace
func ReadCSISecretFile(path string) string {
	data, err := os.ReadFile(path)
	if err == nil {
		return strings.TrimSpace(string(data))
	}
	return ""
}
