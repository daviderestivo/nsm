#!/bin/bash

echo "Cleaning up OPA policy example..."
kubectl delete ns ns-opa
echo "OPA policy example cleaned up!"
