#!/bin/bash

set -e

echo "Deploying NSM virtual wire example..."

kubectl apply -f namespace.yaml
kubectl apply -f netsvc.yaml
kubectl apply -f nse.yaml -n ns-vwire
kubectl apply -f client-a.yaml -n ns-vwire
kubectl apply -f client-b.yaml -n ns-vwire

echo "Waiting for pods..."
kubectl wait --for=condition=ready --timeout=2m pod -l app=client-a -n ns-vwire
kubectl wait --for=condition=ready --timeout=2m pod -l app=client-b -n ns-vwire
kubectl wait --for=condition=ready --timeout=2m pod -l app=nse-vwire -n ns-vwire

echo "Testing connectivity..."
kubectl exec client-a -n ns-vwire -- ping -c 2 172.16.2.2
kubectl exec client-b -n ns-vwire -- ping -c 2 172.16.2.1

echo "Virtual wire example deployed successfully!"
