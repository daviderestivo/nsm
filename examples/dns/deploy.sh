#!/bin/bash

set -e

echo "Deploying NSM DNS example..."

kubectl apply -f namespace.yaml
kubectl apply -f netsvc.yaml
kubectl apply -f dns-config.yaml -n ns-dns
kubectl apply -f dns-server.yaml -n ns-dns
kubectl apply -f nse.yaml -n ns-dns
kubectl apply -f client.yaml -n ns-dns

echo "Waiting for pods..."
kubectl wait --for=condition=ready --timeout=2m pod -l app=dns-client -n ns-dns
kubectl wait --for=condition=ready --timeout=2m pod -l app=dns-server -n ns-dns
kubectl wait --for=condition=ready --timeout=2m pod -l app=nse-dns -n ns-dns

echo "Testing DNS resolution..."
kubectl exec dns-client -n ns-dns -- nslookup test.local 172.16.3.100

echo "DNS example deployed successfully!"
