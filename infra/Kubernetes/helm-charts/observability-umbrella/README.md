# Observability Stack (Shared / Production)

This Helm chart wraps the upstream [`kube-prometheus-stack`](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) to provide Grafana, Prometheus, Alertmanager, and node metrics collection for the shared Kubernetes environment.

It is pinned to chart version `92.11.0` (appVersion `v0.94.1`) and intended for Kubernetes k3s.

## Components

The stack includes:

- **Prometheus Operator** - manages Prometheus and Alertmanager instances
- **Prometheus** - metrics collection and querying
- **Alertmanager** - alert routing and silencing
- **Grafana** - dashboards and visualization
- **kube-state-metrics** - Kubernetes object metrics
- **node-exporter** - node-level metrics

## Service Names and Ports

After installing this chart with release name `observability-umbrella`, the following Services are created in the `platform-observability` namespace:

| Component      | Service Name                              | Port  | Notes                           |
|----------------|-------------------------------------------|-------|---------------------------------|
| Grafana        | `observability-umbrella-grafana`          | 80    | → container port 3000           |
| Prometheus     | `observability-umbrella-kub-prometheus`   | 9090  |                                 |
| Alertmanager   | `observability-umbrella-kub-alertmanager` | 9093  |                                 |
| kube-state-metrics | `observability-umbrella-kube-state-metrics` | 8080 |                            |
| node-exporter  | `observability-umbrella-prometheus-node-exporter` | 9100 |                        |

## Local / Direct Access

### Via Traefik (production)

Traefik IngressRoute resources are located in `infra/Kubernetes/templates/traefik/observability-ingressroute.yaml`. Before applying:

1. Configure DuckDNS hostnames for Grafana and Prometheus. The production DuckDNS domain is `nextcloud-demo-flourishing` — each sub-domain must be registered in the DuckDNS account and the terraform.yml workflow must update them (currently only updates `nextcloud-demo-flourishing`).
2. Replace placeholder hostnames (`grafana-placeholder.flourishing.workers.dev`, `prometheus-placeholder.flourishing.workers.dev`) with actual hostnames.

### Via port-forward

For direct access bypassing Traefik:

```bash
# Grafana
kubectl -n platform-observability port-forward svc/observability-umbrella-grafana 3000:80

# Prometheus
kubectl -n platform-observability port-forward svc/observability-umbrella-kub-prometheus 9090:9090
```

## Admin Credentials (Grafana)

### SealedSecrets

Grafana admin credentials are provisioned via **Bitnami SealedSecrets** — never committed in plaintext.

1. **Create the SealedSecret** (see `infra/Kubernetes/templates/sealed-secrets/grafana-admin.sealedsecret.yaml.example`):

   ```bash
   kubectl -n platform-observability create secret generic grafana-admin \
     --from-literal=admin-user=admin \
     --from-literal=admin-password=<your-password> \
     --dry-run=client -o yaml \
     | kubeseal --controller-namespace default --format yaml \
     | kubectl apply -f -
   ```

   The `kubeseal` tool fetches the sealed-secrets controller's public key from the `default` namespace and encrypts the secret. The resulting `SealedSecret` manifest can be applied to any cluster that has the same controller.

2. The chart value `grafana.admin.existingSecret: grafana-admin` tells Grafana to read `admin-user` and `admin-password` from the Kubernetes Secret named `grafana-admin`.

3. After the SealedSecrets controller decrypts the secret, retrieve the password:

   ```bash
   kubectl -n platform-observability get secret grafana-admin \
     -o jsonpath='{.data.admin-password}' | base64 -d
   ```

### Rotation

To rotate the Grafana admin password:

1. Generate a new random password (or use an existing one).
2. Create a new plain Secret and seal it with kubeseal (as above).
3. `kubectl apply` the new SealedSecret (it replaces the previous one).
4. The Grafana pod will pick up the new credentials on its next restart. Restart if needed:

   ```bash
   kubectl -n platform-observability rollout restart deployment/observability-umbrella-grafana
   ```

## Alertmanager Configuration

### Receiver

The Alertmanager is configured with a **"null" receiver** — alerts are evaluated by Prometheus and routed to the receiver, but no notification is sent. This is the standard "blackhole" pattern for environments without an active notification channel.

The configuration is at `alertmanager.config` in `values.yaml`. The `null` receiver is valid but intentionally has no integrations.

### Adding a Notification Channel

To route alerts to a notification channel, edit `values.yaml` under `alertmanager.config.receivers`:

- **Slack**: Add `slack_configs` with the webhook URL (store in a GitHub secret).
- **Webhook**: Add `webhook_configs` pointing to an internal service.
- **Email**: Add `email_configs` with SMTP credentials (store in GitHub secrets).
- **PagerDuty**: Add `pagerduty_configs` with the service key (GitHub secret).

Example for Slack:

```yaml
alertmanager:
  config:
    receivers:
      - name: "slack"
        slack_configs:
          - channel: "#ops-alerts"
            api_url: "https://hooks.slack.com/services/..."
      - name: "null"  # Keep as fallback
```

Set the route to use `"slack"` instead of `"null"`:

```yaml
alertmanager:
  config:
    route:
      receiver: "slack"
```

## Storage

The Prometheus TSDB and Alertmanager state use PersistentVolumeClaims on the `local-path` StorageClass (k3s default). They survive Pod restarts but are deleted with the release.

Grafana uses an emptyDir volume - dashboards created through the UI are lost when the Pod restarts. Manually created dashboards should be exported and imported as JSON.

## Validation Commands

Before installing, validate the chart with:

```bash
# From this directory
helm dependency build .

helm lint .

# Template the release to inspect the generated resources
helm template observability-umbrella . -n platform-observability --kube-version 1.35.5
```

## Installing

Apply the platform namespaces first (admin-managed):

```bash
kubectl apply -f ../../../templates/namespaces/platform-namespaces.yaml
```

Create the Grafana admin SealedSecret (see [Admin Credentials](#admin-credentials-grafana) above).

Then install the chart:

```bash
helm dependency build .

helm upgrade --install observability-umbrella . \
  -n platform-observability \
  --create-namespace
```

## Uninstalling

To remove the stack:

```bash
helm uninstall observability-umbrella -n platform-observability
```

The PersistentVolumeClaims for Prometheus and Alertmanager must be deleted separately if desired:

```bash
kubectl -n platform-observability delete pvc -l app.kubernetes.io/instance=observability-umbrella
```

## Known Limitations

### Control Plane Metrics

In k3s, the control plane components (etcd, kube-scheduler, kube-controller-manager, kube-proxy) bind their metrics endpoints to localhost only. Their corresponding ServiceMonitors in this chart produce permanently DOWN targets.

They are disabled by default in `values.yaml`:

- `kubeEtcd.enabled: false`
- `kubeScheduler.enabled: false`
- `kubeControllerManager.enabled: false`
- `kubeProxy.enabled: false`

CoreDNS metrics work (runs as Deployment) and are enabled.

### ServiceMonitor Discovery

By default (`serviceMonitorSelectorNilUsesHelmValues: true`), Prometheus discovers ServiceMonitors only in its own namespace (`platform-observability`) or those labeled with:

```yaml
app.kubernetes.io/instance: observability-umbrella
```

To scrape metrics from applications in other namespaces (e.g., `platform-nextcloud`):

1. Deploy a ServiceMonitor in that namespace.
2. Add the label:

   ```yaml
   metadata:
     labels:
       app.kubernetes.io/instance: observability-umbrella
   ```

Alternatively, to discover all ServiceMonitors cluster-wide, override in `values.yaml`:

```yaml
kube-prometheus-stack:
  prometheus:
    prometheusSpec:
      serviceMonitorSelector: {}
```

This lowers isolation but removes the labeling requirement.

### Traefik IngressRoutes

The shared Traefik IngressRoute in `infra/Kubernetes/templates/traefik/observability-ingressroute.yaml` uses **placeholder hostnames** (`grafana-placeholder.flourishing.workers.dev`, `prometheus-placeholder.flourishing.workers.dev`). These must be replaced with actual DuckDNS hostnames before the routes can match traffic.

DuckDNS subdomains must be registered in the DuckDNS account and the terraform.yml workflow must be updated to set the A record for each new sub-domain to the k3s node's public IP.

### Alertmanager Notifications

The Alertmanager `null` receiver drops all alerts silently. No notifications are sent. See [Alertmanager Configuration](#alertmanager-configuration) above for how to add a notification channel.
