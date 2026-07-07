// Copyright IBM Corp. 2024, 2026

package main

import (
	"log"
	"net/http"
	"time"

	"github.com/benoitblais-hashicorp-demo/AWS-EKS-VSOwithCSI/container/demo-go-web-vso-csi/internal/app"
	"github.com/benoitblais-hashicorp-demo/AWS-EKS-VSOwithCSI/container/demo-go-web-vso-csi/internal/controller"
)

func main() {
	router := app.StartUp()
	router.GET("/", controller.GetStaticPage)

	server := &http.Server{
		Addr:         ":8080",
		WriteTimeout: time.Second * 1800,
		ReadTimeout:  time.Second * 1800,
		IdleTimeout:  time.Second * 1800,
		Handler:      router,
	}

	if err := server.ListenAndServe(); err != nil {
		log.Fatalln(" * ERROR: ", err)
	}
}
