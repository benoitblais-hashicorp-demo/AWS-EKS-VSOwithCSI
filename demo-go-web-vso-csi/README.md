# Demo Web App Container Source

This folder vendors the source code for the VSO static-secret demo web application.

## Build image locally

From this folder:

```bash
docker build -t <your-registry>/<your-image>:<tag> -f build/Dockerfile .
```

Example:

```bash
docker build -t 353671346900.dkr.ecr.ca-central-1.amazonaws.com/demo-go-web:v1.1.0 -f build/Dockerfile .
```

## Push image

```bash
docker push <your-registry>/<your-image>:<tag>
```

## Use image in Terraform Stacks

Set stack variable `demo_webapp_image` to your pushed image reference.

Example:

```hcl
demo_webapp_image = "353671346900.dkr.ecr.ca-central-1.amazonaws.com/demo-go-web:v1.1.0"
```
