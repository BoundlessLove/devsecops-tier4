#!/bin/bash

echo "Checking namespaces..."
kubectl get ns

echo "Deleting incorrect cloudflare namespace..."
kubectl delete namespace cloudflare --ignore-not-found

echo "Deleting old staging resources..."
kubectl delete all --all -n staging --ignore-not-found
kubectl delete ingress --all -n staging --ignore-not-found

echo "Deleting old prod resources..."
kubectl delete all --all -n prod --ignore-not-found
kubectl delete ingress --all -n prod --ignore-not-found

echo "Deleting old Helm releases..."
helm uninstall aks-demo-staging -n staging --ignore-not-found
helm uninstall aks-demo -n prod --ignore-not-found
helm uninstall cloudflared-staging -n cloudflare --ignore-not-found
helm uninstall cloudflared-prod -n cloudflare --ignore-not-found

echo "Deleting old ingress-nginx (optional)..."
helm uninstall ingress-nginx -n ingress-nginx --ignore-not-found
kubectl delete namespace ingress-nginx --ignore-not-found

echo "Cleanup complete."
