# terraform-aws-serverless-ggx

Terraform for running GenGuardX on AWS with ECS Fargate.

- one ECS service on an existing cluster
- a single Fargate task definition with:
  - `corridor-migration`
  - `redis`
  - `corridor-app`
  - `corridor-worker`
  - `corridor-jupyter`
- public ALB routing `/` to the app container on port `5002`
- ALB path routing `/jupyter` to the Jupyter container on port `5003`
- shared persistent storage via EFS access points
- optional Aurora PostgreSQL Serverless v2 database

## What It Provisions

- ECS task definition and service on an existing ECS cluster
- Application Load Balancer, listeners, and target groups
- EFS file system, mount targets, and access points
- optional Aurora PostgreSQL Serverless v2 cluster and subnet/security group wiring
- IAM task execution and task roles
- CloudWatch log group
- security groups for ALB, ECS tasks, EFS, and the optional database

## Configure

Update `terraform.tfvars` from `terraform.tfvars.example`:

- `image`
- `hostname`
- `certificate_arn`
- `database_url` or enable `create_database`
- `license_key`

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
