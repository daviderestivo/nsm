#!/bin/bash

set -e

echo "Deploying NSM OPA policy example..."

kubectl apply -f namespace.yaml
kubectl apply -f netsvc.yaml
kubectl apply -f opa-policy.yaml -n ns-opa
kubectl apply -f opa-config.yaml -n ns-opa
kubectl apply -f nse.yaml -n ns-opa
kubectl apply -f server.yaml -n ns-opa
kubectl apply -f client.yaml -n ns-opa

echo "Waiting for pods..."
kubectl wait --for=condition=ready --timeout=2m pod -l app=opa-client -n ns-opa
kubectl wait --for=condition=ready --timeout=2m pod -l app=opa-server -n ns-opa
kubectl wait --for=condition=ready --timeout=2m pod -l app=nse-opa -n ns-opa

echo "Testing policy enforcement..."
echo "Public access (should work):"
kubectl exec opa-client -n ns-opa -- curl -s -H "X-User: alice" http://172.16.5.20/public/info

echo "Admin access with manager (should work):"
kubectl exec opa-client -n ns-opa -- curl -s -H "X-User: bob" http://172.16.5.20/admin/users

echo "Admin access with user (should fail):"
kubectl exec opa-client -n ns-opa -- curl -s -H "X-User: alice" http://172.16.5.20/admin/users || echo "Access denied as expected"

echo "OPA policy example deployed successfully!"
