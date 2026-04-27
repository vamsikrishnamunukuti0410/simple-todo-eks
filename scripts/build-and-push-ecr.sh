#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==> AWS ECR Image Build and Push Script${NC}"

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${AWS_REGION:-us-east-1}
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo -e "${GREEN}AWS Account ID: ${AWS_ACCOUNT_ID}${NC}"
echo -e "${GREEN}AWS Region: ${AWS_REGION}${NC}"
echo -e "${GREEN}ECR Registry: ${ECR_REGISTRY}${NC}"

# Create ECR repositories if they don't exist
echo -e "\n${BLUE}==> Creating ECR repositories${NC}"
aws ecr create-repository --repository-name todo-backend --region ${AWS_REGION} 2>/dev/null || echo "Repository todo-backend already exists"
aws ecr create-repository --repository-name todo-frontend --region ${AWS_REGION} 2>/dev/null || echo "Repository todo-frontend already exists"

# Login to ECR
echo -e "\n${BLUE}==> Logging in to ECR${NC}"
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}

# Build and push backend
echo -e "\n${BLUE}==> Building backend image${NC}"
docker build -t todo-backend:latest ./backend
docker tag todo-backend:latest ${ECR_REGISTRY}/todo-backend:latest

echo -e "${BLUE}==> Pushing backend image${NC}"
docker push ${ECR_REGISTRY}/todo-backend:latest

# Build and push frontend
echo -e "\n${BLUE}==> Building frontend image${NC}"
docker build -t todo-frontend:latest ./frontend
docker tag todo-frontend:latest ${ECR_REGISTRY}/todo-frontend:latest

echo -e "${BLUE}==> Pushing frontend image${NC}"
docker push ${ECR_REGISTRY}/todo-frontend:latest

echo -e "\n${GREEN}✅ Images successfully pushed to ECR!${NC}"
echo -e "${GREEN}Backend: ${ECR_REGISTRY}/todo-backend:latest${NC}"
echo -e "${GREEN}Frontend: ${ECR_REGISTRY}/todo-frontend:latest${NC}"

# Save image URIs to a file for K8s manifests
cat > ./scripts/image-uris.txt <<EOF
BACKEND_IMAGE=${ECR_REGISTRY}/todo-backend:latest
FRONTEND_IMAGE=${ECR_REGISTRY}/todo-frontend:latest
EOF

echo -e "\n${GREEN}Image URIs saved to scripts/image-uris.txt${NC}"
