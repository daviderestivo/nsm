#!/bin/bash

set -e

echo "Deploying NSM secure tunnel example..."

kubectl apply -f namespace.yaml
kubectl apply -f netsvc.yaml
kubectl apply -f nse.yaml -n ns-tunnel
kubectl apply -f server.yaml -n ns-tunnel
kubectl apply -f client.yaml -n ns-tunnel

echo "Waiting for pods..."
kubectl wait --for=condition=ready --timeout=2m pod -l app=tunnel-client -n ns-tunnel
kubectl wait --for=condition=ready --timeout=2m pod -l app=tunnel-server -n ns-tunnel
kubectl wait --for=condition=ready --timeout=2m pod -l app=nse-tunnel -n ns-tunnel

echo "Testing secure connection..."
kubectl exec tunnel-client -n ns-tunnel -- wget -qO- http://172.16.4.20 | head -5

echo "Secure tunnel example deployed successfully!"
