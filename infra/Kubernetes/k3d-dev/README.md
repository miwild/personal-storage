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
- `portfolio-app-1` through `portfolio-app-6` - Individual namespaces for each application
- `shared-services` - Common services shared across applications

## RBAC Model

The coding agent uses a least-privilege model:

- Service account `pi-agent` operates only in `agent-dev` namespace
- For portfolio applications, separate RoleBindings grant necessary permissions
- Cluster administrator is responsible for creating namespaces and RoleBindings

## Traefik Routing

We use explicit Traefik IngressRoute resources for routing:

- Each application gets its own IngressRoute
- Shared TLS configuration via LetsEncrypt certResolver
- Nextcloud routing is preserved in the default namespace
- Portfolio applications use `.local.example.com` domain pattern

## Validation

Run `./validation.sh` to check:
- Namespace accessibility
- RBAC permissions
- Traefik capabilities
- Portfolio namespace access