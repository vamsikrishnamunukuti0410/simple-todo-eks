# Simple Todo App on AWS EKS

A minimal 3-tier Todo application for learning Kubernetes on AWS EKS.

## Architecture

```
Frontend (React) → Backend (Node.js) → Database (MongoDB)
```

## Structure

```
.
├── frontend/          # React app
├── backend/           # Node.js API
├── k8s/              # Kubernetes manifests
└── docker-compose.yml # Local testing
```

## Quick Start

### Local (Docker Compose)
```bash
docker-compose up
# Frontend: http://localhost:3000
# API: http://localhost:5000
```

### AWS EKS
```bash
# 1. Create cluster
eksctl create cluster --name todo-cluster --region us-east-1

# 2. Deploy
kubectl apply -f k8s/

# 3. Get URL
kubectl get ingress
```

That's it!
