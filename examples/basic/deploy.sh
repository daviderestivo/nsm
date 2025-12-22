#!/bin/bash

set -e

echo "Deploying basic NSM kernel2kernel example..."

# Create namespace
kubectl apply -f namespace.yaml

# Deploy network service
kubectl apply -f netsvc.yaml

# Deploy NSE (server)
kubectl apply -f nse-base.yaml -n ns-kernel2kernel

# Deploy NSC (client)
kubectl apply -f client.yaml -n ns-kernel2kernel

echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready --timeout=2m pod -l app=alpine -n ns-kernel2kernel
kubectl wait --for=condition=ready --timeout=2m pod -l app=nse-kernel -n ns-kernel2kernel

echo "Testing connectivity..."
kubectl exec alpine -n ns-kernel2kernel -- ping -c 4 172.16.1.100

echo "Basic NSM example deployed successfully!"
echo "To test manually: kubectl exec alpine -n ns-kernel2kernel -- ping -c 4 172.16.1.100"
