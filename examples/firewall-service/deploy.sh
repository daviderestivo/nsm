#!/bin/bash
set -e

echo "Deploying NSM Firewall Service Example"
echo "======================================"
echo ""

# Check if NSM is installed
if ! kubectl get ns nsm-system > /dev/null 2>&1; then
    echo "❌ NSM system not found. Please install NSM first using:"
    echo "   cd ../eks-cluster && make install-nsm"
    exit 1
fi

echo "✓ NSM system detected"
echo ""

# Deploy firewall service
echo "Deploying firewall service..."
kubectl apply -f firewall-service.yaml
echo "✓ Firewall service deployed"
echo ""

# Deploy client and server
echo "Deploying client and server applications..."
kubectl apply -f client-server.yaml
echo "✓ Client and server deployed"
echo ""

echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available deployment/nsm-firewall --timeout=120s
kubectl wait --for=condition=available deployment/client --timeout=120s
kubectl wait --for=condition=available deployment/server --timeout=120s

echo ""
echo "✅ Deployment completed successfully!"
echo ""
echo "Next steps:"
echo "1. Run tests: ./test.sh"
echo "2. View firewall logs: kubectl logs -l app=nsm-firewall -f"
echo "3. Test manually: kubectl exec -it \$(kubectl get pod -l app=client -o jsonpath='{.items[0].metadata.name}') -- curl http://server:8080/health"
