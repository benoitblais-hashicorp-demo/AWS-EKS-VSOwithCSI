# Demo Web App Container Source

This folder vendors the source code for the VSO static-secret demo web application.

## Build image locally

From this folder:

```bash
docker build -t <your-registry>/<your-image>:<tag> -f build/Dockerfile .
```

Example (GitHub Container Registry):

```bash
docker build -t ghcr.io/benoitblais-hashicorp-demo/demo-go-web-vso-csi:v1.2.0 -f build/Dockerfile .
```

## Push image

Ensure you are logged into the registry first (e.g. `docker login ghcr.io -u <username> -p <token>`), then:

```bash
docker push ghcr.io/benoitblais-hashicorp-demo/demo-go-web-vso-csi:v1.2.0
```

## Use image in Terraform

Set the `demo_webapp_image` variable in your workspace to point to your new image.

Example:

```hcl
demo_webapp_image = "ghcr.io/benoitblais-hashicorp-demo/demo-go-web-vso-csi:v1.2.0"
```
