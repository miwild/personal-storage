#!/bin/bash

# Enhanced K3D Dev Environment Validation Script

echo "=== K3D Dev Environment Validation ==="

echo "1. Checking agent-dev namespace..."
kubectl get pods -n agent-dev >/dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✓ agent-dev namespace accessible"
else
  echo "✗ agent-dev namespace not accessible"
fi

echo "2. Checking available namespaces..."
NAMESPACES=$(kubectl get ns 2>/dev/null | grep -E "(agent-dev|platform)" || echo "")
if [ -n "$NAMESPACES" ]; then
  echo "✓ Platform namespaces found:"
  echo "$NAMESPACES" | awk '{print "  - " $1}'
else
  echo "⚠ Platform namespaces not found (may not be created yet)"
fi

echo "3. Checking RBAC permissions..."
kubectl auth can-i get pods -n agent-dev >/dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✓ Can get pods in agent-dev"
else
  echo "✗ Cannot get pods in agent-dev"
fi

kubectl auth can-i create deployments -n agent-dev >/dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✓ Can create deployments in agent-dev"
else
  echo "✗ Cannot create deployments in agent-dev"
fi

echo "4. Checking Traefik availability..."
kubectl get crd ingressroutes.traefik.io >/dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✓ Traefik CRDs available"
else
  echo "⚠ Traefik CRDs not found"
fi

# Test if we can create an ingressroute in our namespace
echo "5. Testing IngressRoute creation permissions..."
TMPFILE=$(mktemp)
cat > $TMPFILE <<EOF
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: validation-test-route
  namespace: agent-dev
spec:
  entryPoints:
    - web
  routes:
    - match: Host(\`validation.test.local\`)
      kind: Rule
      services:
        - name: validation-test-service
          port: 80
EOF

kubectl apply -f $TMPFILE >/dev/null 2>&1
RESULT=$?
rm $TMPFILE

if [ $RESULT -eq 0 ]; then
  echo "✓ Can create IngressRoute in agent-dev"
  # Clean up
  kubectl delete ingressroute validation-test-route -n agent-dev >/dev/null 2>&1
else
  echo "✗ Cannot create IngressRoute in agent-dev"
fi

echo "6. Checking portfolio namespace permissions..."
PLATFORM_NAMESPACES=("platform-nextcloud" "platform-observability" "platform-argocd" "platform-backstage" "platform-trivy" "platform-glitchtip")
for NAMESPACE in "${PLATFORM_NAMESPACES[@]}"; do
  kubectl auth can-i get pods -n $NAMESPACE >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "✓ Can access $NAMESPACE"
  else
    echo "⚠ Cannot access $NAMESPACE (may not exist yet)"
  fi
done

echo "Validation complete."