# Nextcloud Deployment Demo

This project demonstrates automated cloud infrastructure provisioning and application deployment using **AWS, Terraform, Kubernetes, and Helm**.

The demo uses Cloudflare and GitHub Actions to trigger deployment on demand. The environment is temporary and automatically cleaned up to keep running costs low.

**Try the demo:** [Open Nextcloud Demo](https://nextcloud-demo.flourishing.workers.dev)

**Source code:** [miwild/personal-storage](https://github.com/miwild/personal-storage)

## Demo Credentials

<details>
<summary>Username</summary>

`admin`

</details>

<details>
<summary>Password</summary>

`somepassword`

</details>

## Technologies

- **AWS** — Cloud infrastructure and networking
- **Terraform** — Infrastructure as code
- **Kubernetes (k3s)** — Container orchestration
- **Helm** — Application deployment and configuration
- **GitHub Actions** — Automated provisioning and cleanup
- **Cloudflare Workers & Pages** — Demo frontend and deployment trigger
- **Nextcloud** — Self-hosted file storage application

## Development Environment

The development environment uses the same infrastructure code but with isolated state files (prefixed with `dev/`). Unlike production, dev environments are not automatically cleaned up and will continue incurring charges until manually destroyed. It is recommended to set up AWS budget alerts to monitor costs.
