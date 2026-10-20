# Dev Environment for Personal Storage

This directory contains the isolated development environment for the personal-storage project.

## Architecture

The dev environment mirrors the production architecture but with the following differences:

1. **Separate State**: All Terraform state is stored under `dev/` prefix in the same S3 bucket
2. **Resource Naming**: All resources are suffixed with `-dev` to distinguish from production
3. **Network Isolation**: Uses different CIDR blocks (10.1.0.0/16 vs 10.0.0.0/16)
4. **Security**: No public SSH access by default
5. **Minimal Dependencies**: Avoids dependencies on production resources where possible

## State Keys

All dev state is stored in the same bucket as production but with different keys:

- AWS: `dev/nextcloud/AWS/terraform.tfstate`
- RDS: `dev/nextcloud/RDS/terraform.tfstate`
- ACM: `dev/nextcloud/ACM/terraform.tfstate`

## Directory Structure

```
infra/dev/
├── ACM/          # Certificate management (minimal in dev)
├── AWS/          # Main infrastructure (VPC, EC2, etc.)
├── RDS/          # Database resources
├── policies/     # IAM policies for dev environment
├── scripts/      # Utility scripts for validation, planning, etc.
├── tests/        # Test cases for dev environment
└── docs/         # Documentation
```

## Credential Setup

To work with the dev environment, you need:

1. AWS credentials with permissions defined in `policies/dev-terraform-policy.json`
2. The dev environment uses the same AWS account as production, so IAM policies are critical
3. Terraform backend uses the same S3 bucket but with `dev/` prefix for isolation

## Scripts

- `scripts/validate.sh`: Validates Terraform configurations without creating resources
- `scripts/plan.sh`: Plans changes to the dev environment
- `scripts/apply.sh`: Applies changes to the dev environment (creates resources)
- `scripts/cleanup.sh`: Destroys all dev resources
- `scripts/isolation_check.sh`: Verifies dev environment doesn't reference production

## Testing

Run tests with:
```bash
terraform test
```

Tests verify:
- Dev resource names are correct
- Backend keys use dev prefix
- No production state keys are referenced
- No public SSH access is configured

## Cost Considerations

The dev environment uses the same instance types as production:
- t3.small for EC2 instances
- db.t3.micro for RDS instances

These are relatively inexpensive but will incur charges while running.

Set up billing alerts to monitor costs.

## Security Boundary

Important: Naming and separate state are NOT security boundaries.

We share one AWS account, so:
- IAM policy is the real boundary
- Account-ID check can't tell dev from prod
- Always verify backend keys before applying changes

## Manual Bootstrap

1. Ensure AWS credentials are configured
2. Review and customize `terraform.tfvars`
3. Run `scripts/validate.sh` to check configurations
4. Run `scripts/plan.sh` to see what will be created
5. Run `scripts/apply.sh` to create resources (manual confirmation required)
6. Run `scripts/cleanup.sh` to destroy resources when finished (manual confirmation required)