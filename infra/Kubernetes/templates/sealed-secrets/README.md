# Sealed Secrets for the Platform

This directory contains templates and documentation for Bitnami SealedSecrets
used across the platform (Grafana admin credentials, database secrets, etc.).

## How It Works

1. A plain Kubernetes Secret is created with `kubectl create secret generic ... --dry-run=client -o yaml`.
2. The YAML is piped to `kubeseal --controller-namespace default --format yaml`, which encrypts it using the sealed-secrets controller's public key.
3. The resulting `SealedSecret` manifest is applied via `kubectl apply -f -`.
4. The sealed-secrets controller (deployed in the `default` namespace) watches for `SealedSecret` resources and creates the corresponding plain `Secret` objects.

## Grafana Admin Credentials

See:
- Template: `grafana-admin.sealedsecret.yaml.example` (documented structure, not deployable)
- Values reference: `infra/Kubernetes/helm-charts/observability-umbrella/values.yaml` → `grafana.admin.existingSecret`
- Deployment workflow: `.github/workflows/observability-deploy.yml`

## Rotating Credentials

```bash
# 1. Create a new plain secret and seal it:
kubectl -n platform-observability create secret generic grafana-admin \
  --from-literal=admin-user=admin \
  --from-literal=admin-password=NEW_PASSWORD \
  --dry-run=client -o yaml \
  | kubeseal --controller-namespace default --format yaml \
  | kubectl apply -f -

# 2. Restart Grafana to pick up new credentials:
kubectl -n platform-observability rollout restart deployment/observability-umbrella-grafana
```

## Common Mistakes

- **Never commit plaintext secrets** (passwords, tokens, keys) to the repository.
- **The SealedSecret must be sealed with the same controller's key** — if the controller is reinstalled with new keys, existing sealed secrets stop working.
- **kubeseal must connect to the correct controller namespace** — the sealed-secrets controller is deployed in the `default` namespace by the nextcloud-umbrella chart.
