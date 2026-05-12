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

echo "Updating ECS task definition with new image..."
TASK_DEF_JSON=$(aws ecs describe-task-definition \
  --task-definition flask-devops-task \
  --query 'taskDefinition' \
  --region "$AWS_REGION")

NEW_TASK_DEF=$(echo "$TASK_DEF_JSON" | python3 -c "
import json, sys
td = json.load(sys.stdin)
td['containerDefinitions'][0]['image'] = '$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG'
for key in ['taskDefinitionArn','revision','status','requiresAttributes',
            'placementConstraints','compatibilities','registeredAt','registeredBy']:
    td.pop(key, None)
print(json.dumps(td))
")

echo "Registering new task definition revision..."
NEW_TASK_DEF_ARN=$(aws ecs register-task-definition \
  --cli-input-json "$NEW_TASK_DEF" \
  --region "$AWS_REGION" \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

echo "Deploying to ECS with new task definition: $NEW_TASK_DEF_ARN"
aws ecs update-service \
  --cluster flask-devops-cluster \
  --service flask-devops-service \
  --task-definition "$NEW_TASK_DEF_ARN" \
  --region "$AWS_REGION"

echo "Waiting for deployment to stabilise..."
aws ecs wait services-stable \
  --cluster flask-devops-cluster \
  --services flask-devops-service \
  --region "$AWS_REGION"

echo "Done. Image: $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG"
