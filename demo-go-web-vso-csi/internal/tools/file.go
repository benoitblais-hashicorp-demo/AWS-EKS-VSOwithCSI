// Copyright IBM Corp. 2024, 2026

package tools

import (
	"encoding/json"
	"os"
)

type ConfigFile struct {
	Message  string `json:"message"`
	ImageURL string `json:"image_url"`
}

func GetConfigFromFile(path string) ConfigFile {
	var cfg ConfigFile
	data, err := os.ReadFile(path)
	if err == nil {
		_ = json.Unmarshal(data, &cfg)
	}
	return cfg
}
