#!/bin/bash
set -e

echo "Cleaning up NSM Firewall Service Example"
echo "========================================"
echo ""

echo "Deleting client and server applications..."
kubectl delete -f client-server.yaml --ignore-not-found=true
echo "✓ Client and server deleted"

echo "Deleting firewall service..."
kubectl delete -f firewall-service.yaml --ignore-not-found=true
echo "✓ Firewall service deleted"

echo ""
echo "✅ Cleanup completed successfully!"
