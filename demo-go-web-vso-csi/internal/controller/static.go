// Copyright IBM Corp. 2024, 2026

package controller

import (
	"github.com/benoitblais-hashicorp-demo/AWS-EKS-VSOwithCSI/container/demo-go-web-vso-csi/internal/tools"
	"github.com/gin-gonic/gin"
)

func GetStaticPage(c *gin.Context) {
	// Attempt to read the CSI mounted secret from the expected path
	cfg := tools.GetConfigFromFile("/var/run/secrets/vault/app/config")

	// Fallback to environment variables if the file/keys are missing
	firstMessage := cfg.Message
	if firstMessage == "" {
		firstMessage = tools.GetEnvVariable("FIRST_MESSAGE", "")
	}

	centralImage := cfg.ImageURL
	if centralImage == "" {
		centralImage = tools.GetEnvVariable("IMAGE_URL", "https://avatars.githubusercontent.com/u/320148?v=4")
	}

	c.HTML(200, "static.html", gin.H{
		"Title":        tools.GetEnvVariable("TITLE", ""),
		"SubTitle":     tools.GetEnvVariable("SUB_TITLE", ""),
		"FirstMessage": firstMessage,
		"CentralImage": centralImage,
		"LearnMoreURL": tools.GetEnvVariable("LEARN_LINK", ""),
	})
}
