#!/bin/bash
set -e

echo "Testing NSM Firewall Service"
echo "=============================="
echo ""

# Wait for pods to be ready
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=nsm-firewall --timeout=120s
kubectl wait --for=condition=ready pod -l app=client --timeout=120s
kubectl wait --for=condition=ready pod -l app=server --timeout=120s

echo "✓ All pods are ready"
echo ""

# Get pod names
CLIENT_POD=$(kubectl get pod -l app=client -o jsonpath='{.items[0].metadata.name}')
SERVER_POD=$(kubectl get pod -l app=server -o jsonpath='{.items[0].metadata.name}')
FIREWALL_POD=$(kubectl get pod -l app=nsm-firewall -o jsonpath='{.items[0].metadata.name}')

echo "Pod names:"
echo "  Client:   $CLIENT_POD"
echo "  Server:   $SERVER_POD"
echo "  Firewall: $FIREWALL_POD"
echo ""

# Test 1: HTTP traffic (should be allowed)
echo "Test 1: HTTP traffic on port 8080 (should be ALLOWED)"
if kubectl exec -it $CLIENT_POD -- curl -s --max-time 5 http://server:8080/health > /dev/null 2>&1; then
    echo "✓ HTTP traffic allowed"
else
    echo "✗ HTTP traffic blocked (unexpected)"
fi
echo ""

# Test 2: Check firewall logs
echo "Test 2: Checking firewall logs"
echo "Recent firewall activity:"
kubectl logs $FIREWALL_POD --tail=10
echo ""

# Test 3: Verify NSM connection
echo "Test 3: Verifying NSM connection"
if kubectl exec -it $CLIENT_POD -- ip addr show nsm-1 > /dev/null 2>&1; then
    echo "✓ NSM interface exists"
    kubectl exec -it $CLIENT_POD -- ip addr show nsm-1 | grep "inet "
else
    echo "✗ NSM interface not found"
fi
echo ""

# Test 4: Network connectivity
echo "Test 4: Testing network connectivity"
echo "Ping test:"
if kubectl exec -it $CLIENT_POD -- ping -c 3 server > /dev/null 2>&1; then
    echo "✓ ICMP traffic allowed"
else
    echo "✗ ICMP traffic blocked"
fi
echo ""

# Summary
echo "=============================="
echo "Test Summary"
echo "=============================="
echo "All tests completed. Check logs above for details."
echo ""
echo "To view live firewall logs:"
echo "  kubectl logs -f $FIREWALL_POD"
echo ""
echo "To test manually:"
echo "  kubectl exec -it $CLIENT_POD -- curl http://server:8080/health"
