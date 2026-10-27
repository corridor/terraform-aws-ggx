# terraform-aws-serverless-ggx

Terraform for running GenGuardX on AWS with ECS Fargate.

- one ECS service on an existing cluster, or a new cluster if the name is not found
- a single Fargate task definition with:
  - `corridor-app` (unified API and UI)
  - `corridor-worker` (Jupyter kernel worker on port `5001`)
  - `corridor-jupyter`
- public ALB routing `/` to the app container on port `5002`
- ALB path routing `/jupyter` to the Jupyter container on port `5003`
- shared persistent storage via EFS access points
- optional Aurora PostgreSQL Serverless v2 database

## What It Provisions

- ECS task definition and service, creating the ECS cluster if needed
- Application Load Balancer, listeners, and target groups
- EFS file system, mount targets, and access points
- optional Aurora PostgreSQL Serverless v2 cluster and subnet/security group wiring
- IAM task execution and task roles
- CloudWatch log group
- security groups for ALB, ECS tasks, EFS, and the optional database

## Configure

Update `terraform.tfvars` from `terraform.tfvars.example`:

- `cluster_name` (name of the ECS cluster to reuse or create)
- `image`
- `hostname`
- `certificate_arn`
- `database_url` or enable `create_database`
- `license_key`

The module looks for `cluster_name` in the configured AWS account and region. If it exists, the service uses it without managing or deleting that cluster. Otherwise, `terraform plan` previews a new cluster and `terraform apply` creates it. For example, set `cluster_name = "serverless_demo_terraform"`. The VPC and subnets must already exist. The Terraform identity needs `ecs:ListClusters` for discovery.

The initial cluster selection is saved in Terraform state so subsequent plans keep managing a cluster created by this module. Changing `cluster_name` selects again. Keep the state file: deleting it loses that ownership decision. If an externally managed cluster is later deleted, restore it or replace `terraform_data.cluster_selection` to select again.

To let this module create its own database, set `create_database = true` and provide at least:

- `database_master_password`
- `database_subnet_ids` with at least two subnets, or rely on `public_subnet_ids`

When `create_database = true`, the module provisions an Aurora PostgreSQL Serverless v2 cluster and automatically injects the generated connection string into the ECS task definition. Private subnets are preferred for `database_subnet_ids`. When `create_database = false`, you must continue supplying `database_url`.

## Deploy

```bash
terraform init
terraform plan
terraform apply
```

## Kernel worker and upgrades

The API serves both the UI and `/api` on port `5002`. Redis and Celery are no longer used. The API connects to the kernel worker at its default `http://127.0.0.1:5001`. The worker uses `CORRIDOR_API_URL=http://localhost:5002/` (without `/api`) for API callbacks. Containers in the same Fargate task share localhost, so neither connection needs an ALB route or a public worker port.

The API and worker share `/opt/corridor/kernels` through a root-owned, owner-only EFS access point. The worker is essential and has a TCP health check; the API waits for it to become healthy.

Keep `desired_count = 1` (`0` stops the service). Kernel leases assume one worker, so deployments stop the previous task before starting its replacement. Expect downtime and interruption of running jobs during updates.

Database upgrades are performed through the application UI after deployment, matching the Azure deployment. There is no automatic migration container.

The example uses the `latest` image tag. Supply an image your task execution role can pull; deployments outside the image owner's AWS account also need permission from that ECR repository.
