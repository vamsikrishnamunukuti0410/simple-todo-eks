#!/bin/bash
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==> Updating Kubernetes manifests with ECR image URIs${NC}"

# Source the image URIs
if [ ! -f ./scripts/image-uris.txt ]; then
    echo "Error: image-uris.txt not found. Run build-and-push-ecr.sh first!"
    exit 1
fi

source ./scripts/image-uris.txt

echo -e "${GREEN}Backend Image: ${BACKEND_IMAGE}${NC}"
echo -e "${GREEN}Frontend Image: ${FRONTEND_IMAGE}${NC}"

# Update backend.yaml
sed -i.bak "s|REPLACE_WITH_ECR_BACKEND_IMAGE|${BACKEND_IMAGE}|g" ./k8s/backend.yaml
echo -e "${GREEN}✅ Updated k8s/backend.yaml${NC}"

# Update frontend.yaml
sed -i.bak "s|REPLACE_WITH_ECR_FRONTEND_IMAGE|${FRONTEND_IMAGE}|g" ./k8s/frontend.yaml
echo -e "${GREEN}✅ Updated k8s/frontend.yaml${NC}"

# Remove backup files
rm -f ./k8s/*.bak

echo -e "\n${GREEN}✅ Kubernetes manifests updated successfully!${NC}"
echo -e "${BLUE}You can now deploy with: kubectl apply -f k8s/${NC}"
