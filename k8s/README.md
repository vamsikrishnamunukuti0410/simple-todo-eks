# Production-Grade Kubernetes Manifests

This directory contains production-ready Kubernetes manifests for deploying the Todo application on AWS EKS.

## Architecture Overview

```
Internet → ALB (Ingress) → Frontend (2-5 pods) → Backend (2-5 pods) → MongoDB (StatefulSet)
```

## Files

### Core Application
- **namespace.yaml** - Isolated namespace for the application
- **secrets.yaml** - MongoDB credentials (base64 encoded)
- **configmap.yaml** - Application configuration (non-sensitive)
- **mongodb-statefulset.yaml** - MongoDB with persistent storage
- **backend.yaml** - Node.js API with init containers
- **frontend.yaml** - Nginx web server with init containers
- **ingress.yaml** - AWS Application Load Balancer

### Production Features
- **hpa.yaml** - Horizontal Pod Autoscaler (auto-scaling)
- **pdb.yaml** - Pod Disruption Budgets (high availability)

## Production Features

### 1. **High Availability**
- Multiple replicas (2 minimum)
- Pod anti-affinity (spread across nodes)
- Pod Disruption Budgets (min 1 pod always available)

### 2. **Auto-Scaling**
- HPA scales based on CPU (70%) and memory (80%)
- Backend: 2-5 replicas
- Frontend: 2-5 replicas

### 3. **Security**
- Kubernetes Secrets for credentials
- ConfigMaps for non-sensitive config
- MongoDB authentication enabled

### 4. **Resilience**
- Init containers (wait for dependencies)
- Liveness probes (restart unhealthy pods)
- Readiness probes (traffic only to healthy pods)
- Graceful shutdown (preStop hooks)

### 5. **Database**
- StatefulSet (stable identity)
- Persistent volumes (EBS gp3)
- Health checks

### 6. **Zero-Downtime Deployments**
- Rolling update strategy
- maxUnavailable: 0
- Pod Disruption Budgets

## Deployment Order

```bash
# 1. Create namespace
kubectl apply -f namespace.yaml

# 2. Create secrets and config
kubectl apply -f secrets.yaml
kubectl apply -f configmap.yaml

# 3. Deploy database
kubectl apply -f mongodb-statefulset.yaml

# 4. Deploy application
kubectl apply -f backend.yaml
kubectl apply -f frontend.yaml

# 5. Setup auto-scaling and high availability
kubectl apply -f hpa.yaml
kubectl apply -f pdb.yaml

# 6. Expose via load balancer
kubectl apply -f ingress.yaml
```

## Verification

```bash
# Check all resources
kubectl get all -n todo-app

# Check HPA status
kubectl get hpa -n todo-app

# Check PDB status
kubectl get pdb -n todo-app

# Check pod distribution across nodes
kubectl get pods -n todo-app -o wide

# Check logs
kubectl logs -f deployment/backend -n todo-app
kubectl logs -f deployment/frontend -n todo-app
```

## Interview Talking Points

1. **"How does your app handle traffic spikes?"**
   - HPA automatically scales pods based on CPU/memory metrics

2. **"How do you ensure zero-downtime deployments?"**
   - Rolling updates with maxUnavailable: 0 + PDB + readiness probes

3. **"How do you manage configuration?"**
   - ConfigMaps for non-sensitive data, Secrets for credentials

4. **"Why StatefulSet for MongoDB?"**
   - Stable network identity, ordered deployment, persistent storage

5. **"How do you handle service dependencies?"**
   - Init containers ensure MongoDB is ready before backend starts

6. **"How do you ensure high availability?"**
   - Multiple replicas, pod anti-affinity, PDB, health checks

## Multi-AZ Deployment

The EKS cluster spans 3 availability zones (us-east-1a, us-east-1b, us-east-1c):
- Pods are distributed across zones automatically
- Pod anti-affinity spreads replicas across different nodes
- ALB distributes traffic across all zones
- If one AZ fails, pods in other AZs continue serving traffic
