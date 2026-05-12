#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="105927215341"
ECR_REPOSITORY="flask-devops-app"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_TAG="${1:-latest}"

echo "Logging into ECR..."
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

echo "Building Docker image (tag: $IMAGE_TAG)..."
docker build \
  --target runtime \
  -f docker/Dockerfile \
  -t "$ECR_REPOSITORY:$IMAGE_TAG" \
  ./app

echo "Tagging for ECR..."
docker tag "$ECR_REPOSITORY:$IMAGE_TAG" "$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG"

echo "Pushing to ECR..."
docker push "$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG"

echo "Deploying to ECS..."
aws ecs update-service \
  --cluster flask-devops-cluster \
  --service flask-devops-service \
  --force-new-deployment \
  --region "$AWS_REGION"

echo "Waiting for deployment to stabilise..."
aws ecs wait services-stable \
  --cluster flask-devops-cluster \
  --services flask-devops-service \
  --region "$AWS_REGION"

echo "Done. Image: $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG"
