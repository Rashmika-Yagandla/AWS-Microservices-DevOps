#!/usr/bin/env bash
set -euo pipefail
APP_DIR="${APP_DIR:-/opt/aws-microservices}"
mkdir -p "$APP_DIR"
sudo chown -R ubuntu:ubuntu "$APP_DIR"
cd "$APP_DIR"

# EC2 instance profile supplies ECR pull permissions; no static AWS keys on EC2.
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

# .env is transferred by Jenkins and must contain the image tags and Grafana password.
docker compose pull
docker compose up -d --remove-orphans
docker image prune -f
docker compose ps
