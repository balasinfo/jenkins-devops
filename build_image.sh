#!/bin/sh

# Deploy Jenkins DevOps container locally
# Not in swarm mode

set -e

IMAGE_TAG="2019.06.05"

# ensure latest jenkins image is pulled and used as base images...
docker pull jenkins/jenkins:lts

# build new image
docker build --file Dockerfile \
  --no-cache \
  -t dharamaraob/jenkins:${IMAGE_TAG} .
