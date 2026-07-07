// Copyright IBM Corp. 2024, 2026

package controller

import (
	"github.com/benoitblais-hashicorp-demo/AWS-EKS-VSOwithCSI/container/demo-go-web-vso-csi/internal/tools"
	"github.com/gin-gonic/gin"
)

func GetStaticPage(c *gin.Context) {
	// 1. Attempt to read the CSI mounted secrets directly from the raw VSO file outputs
	// VSO creates files named: static_secret_<index>_<key>
	firstMessage := tools.ReadCSISecretFile("/var/run/secrets/vault/static_secret_0_message")
	
	// Fallback to environment variables if the file is missing
	if firstMessage == "" {
		firstMessage = tools.GetEnvVariable("FIRST_MESSAGE", "")
	}

	centralImage := tools.ReadCSISecretFile("/var/run/secrets/vault/static_secret_0_image_url")
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
