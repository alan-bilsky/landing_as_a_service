#!/bin/bash
set -e

AWS_REGION=${AWS_REGION:-us-west-2}
IMAGE_NAME=${IMAGE_NAME:-puppeteer-lambda-repo}
IMAGE_TAG=${IMAGE_TAG:-latest}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URL="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$IMAGE_NAME:$IMAGE_TAG"

# Go to the puppeteer_lambda module root
d=$(dirname "$0")/..
cd "$d"

# Ensure dependencies are installed
cd build
npm install
cd ..

# Build Docker image
docker build --platform=linux/amd64 -t $IMAGE_NAME:latest .

echo "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

echo "Tagging image..."
docker tag $IMAGE_NAME:latest $ECR_URL

echo "Pushing image to ECR..."
docker push $ECR_URL

echo "Image pushed: $ECR_URL" 