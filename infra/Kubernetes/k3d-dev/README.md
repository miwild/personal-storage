# K3D Development Environment

This directory contains Kubernetes manifests specifically for the k3d development environment.

## Structure

- `templates/namespaces/` - Namespace definitions
- `templates/rbac/` - Role-based access control configurations
- `templates/traefik/` - Traefik ingress configurations
- `helm-charts/` - Environment-specific Helm charts

## Namespace Strategy

For the 6 portfolio applications, we use the following namespace strategy:

- `agent-dev` - Coding agent operations (current namespace)
- `platform-nextcloud` - Nextcloud application
- `platform-observability` - Observability stack (Grafana, Prometheus, Loki)
- `platform-argocd` - ArgoCD continuous delivery
- `platform-backstage` - Backstage developer portal
- `platform-trivy` - Trivy security scanner
- `platform-glitchtip` - GlitchTip error tracking
- `shared-services` - Common services shared across applications

## RBAC Model

The coding agent uses a least-privilege model:

- Service account `pi-agent` operates only in `agent-dev` namespace
- For portfolio applications, separate RoleBindings grant necessary permissions
- Cluster administrator is responsible for creating namespaces and RoleBindings

## Traefik Routing

We use explicit Traefik IngressRoute resources for routing:

- Each application gets its own IngressRoute
- Shared TLS configuration via wildcard certificate secrets
- Each application uses path-based routing where appropriate
- Applications use `.local.example.com` domain pattern for local development

## Validation

Run `./validation.sh` to check:
- Namespace accessibility
- RBAC permissions
- Traefik capabilities
- Platform namespace access