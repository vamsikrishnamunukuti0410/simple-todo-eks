# Deployment Guide: Todo App on AWS EKS

Complete step-by-step guide to deploy the Todo app on AWS EKS using ECR.

---

## Prerequisites

✅ AWS CLI configured (`aws configure`)  
✅ Docker installed  
✅ `eksctl` installed  
✅ `kubectl` installed  
✅ `helm` installed  

---

## Phase 1: Build and Push Images to ECR

### Step 1: Make scripts executable
```bash
cd simple-todo-eks
chmod +x scripts/*.sh
```

### Step 2: Build and push images to ECR
```bash
./scripts/build-and-push-ecr.sh
```

This script will:
- Get your AWS Account ID automatically
- Create ECR repositories (`todo-backend`, `todo-frontend`)
- Build Docker images
- Push to ECR
- Save image URIs to `scripts/image-uris.txt`

**Expected output:**
```
✅ Images successfully pushed to ECR!
Backend: 123456789012.dkr.ecr.us-east-1.amazonaws.com/todo-backend:latest
Frontend: 123456789012.dkr.ecr.us-east-1.amazonaws.com/todo-frontend:latest
```

### Step 3: Update Kubernetes manifests
```bash
./scripts/update-k8s-manifests.sh
```

This replaces placeholders in `k8s/backend.yaml` and `k8s/frontend.yaml` with actual ECR image URIs.

---

## Phase 2: Create EKS Cluster

### Step 1: Create the cluster
```bash
eksctl create cluster \
  --name todo-app-cluster \
  --region us-east-1 \
  --version 1.31 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 3 \
  --managed
```

⏱️ **This takes 15-20 minutes**

### Step 2: Verify cluster
```bash
kubectl get nodes
```

You should see 2 nodes in `Ready` state.

---

## Phase 3: Deploy the Application

### Step 1: Create namespace
```bash
kubectl apply -f k8s/namespace.yaml
```

### Step 2: Deploy MongoDB
```bash
kubectl apply -f k8s/mongodb.yaml
```

Wait for MongoDB to be ready:
```bash
kubectl wait --for=condition=ready pod -l app=mongodb -n todo-app --timeout=120s
```

### Step 3: Deploy Backend
```bash
kubectl apply -f k8s/backend.yaml
```

Check backend pods:
```bash
kubectl get pods -n todo-app -l app=backend
```

### Step 4: Deploy Frontend
```bash
kubectl apply -f k8s/frontend.yaml
```

Check all pods:
```bash
kubectl get pods -n todo-app
```

All pods should be `Running`.

---

## Phase 4: Setup AWS Load Balancer Controller

### Step 1: Setup OIDC provider
```bash
export CLUSTER_NAME=todo-app-cluster
export AWS_REGION=us-east-1

eksctl utils associate-iam-oidc-provider \
  --cluster ${CLUSTER_NAME} \
  --region ${AWS_REGION} \
  --approve
```

### Step 2: Download IAM policy
```bash
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.11.0/docs/install/iam_policy.json
```

### Step 3: Create IAM policy
```bash
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam-policy.json
```

### Step 4: Create IAM service account
```bash
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

eksctl create iamserviceaccount \
  --cluster=${CLUSTER_NAME} \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve \
  --region=${AWS_REGION}
```

### Step 5: Install ALB controller with Helm
```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=${CLUSTER_NAME} \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=${AWS_REGION}
```

### Step 6: Verify ALB controller
```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### Step 7: Tag public subnets
```bash
VPC_ID=$(aws eks describe-cluster --name ${CLUSTER_NAME} --region ${AWS_REGION} \
  --query "cluster.resourcesVpcConfig.vpcId" --output text)

PUBLIC_SUBNETS=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=${VPC_ID}" "Name=map-public-ip-on-launch,Values=true" \
  --query "Subnets[*].SubnetId" \
  --output text \
  --region ${AWS_REGION})

aws ec2 create-tags \
  --resources ${PUBLIC_SUBNETS} \
  --tags Key=kubernetes.io/role/elb,Value=1 \
  --region ${AWS_REGION}
```

---

## Phase 5: Deploy Ingress

### Step 1: Deploy Ingress
```bash
kubectl apply -f k8s/ingress.yaml
```

### Step 2: Wait for ALB to be provisioned
```bash
kubectl get ingress -n todo-app -w
```

Wait until you see an `ADDRESS` (ALB DNS name). Press `Ctrl+C` to stop watching.

### Step 3: Get the ALB URL
```bash
kubectl get ingress todo-app-ingress -n todo-app \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Step 4: Access the app
Open the ALB DNS in your browser:
```
http://<ALB-DNS-NAME>
```

You should see the Todo app! 🎉

---

## Verification

### Check all resources
```bash
kubectl get all -n todo-app
```

### Check logs
```bash
# Backend logs
kubectl logs -n todo-app -l app=backend

# Frontend logs
kubectl logs -n todo-app -l app=frontend

# MongoDB logs
kubectl logs -n todo-app -l app=mongodb
```

### Test the API directly
```bash
ALB_DNS=$(kubectl get ingress todo-app-ingress -n todo-app \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

curl http://${ALB_DNS}/api/todos
```

---

## Cleanup

### Delete all K8s resources
```bash
kubectl delete namespace todo-app
kubectl delete ingress todo-app-ingress -n todo-app
```

### Delete EKS cluster
```bash
eksctl delete cluster --name todo-app-cluster --region us-east-1
```

### Delete ECR repositories
```bash
aws ecr delete-repository --repository-name todo-backend --force --region us-east-1
aws ecr delete-repository --repository-name todo-frontend --force --region us-east-1
```

### Delete IAM policy
```bash
aws iam delete-policy --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy
```

---

## Troubleshooting

### Pods not starting
```bash
kubectl describe pod -n todo-app <pod-name>
kubectl logs -n todo-app <pod-name>
```

### Ingress not creating ALB
```bash
kubectl describe ingress todo-app-ingress -n todo-app
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

### Backend can't connect to MongoDB
```bash
kubectl exec -it -n todo-app <backend-pod-name> -- sh
# Inside pod:
ping mongodb
```

---

## Cost Estimate

- EKS cluster: ~$0.10/hour ($2.40/day)
- 2 x t3.medium nodes: ~$0.08/hour ($1.92/day)
- ALB: ~$0.025/hour ($0.60/day)
- **Total: ~$5/day**

**Remember to delete everything when done!**
