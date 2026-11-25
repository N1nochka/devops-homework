# Lesson 5 — Terraform: S3 Backend, VPC, ECR

## Project structure

- modules/s3-backend — S3 bucket for Terraform state and DynamoDB locking.
- modules/vpc — VPC with 3 public and 3 private subnets, IGW, NAT Gateways and route tables.
- modules/ecr — ECR repository with image scanning and repository access policy.

## Requirements

- Terraform >= 1.5.0
- AWS CLI configured
- AWS account
- Globally unique S3 bucket name

## Deployment

### Phase 1 — Create infrastructure with local state

    terraform fmt -recursive
    terraform init
    terraform validate
    terraform plan -var="bucket_name=YOUR-UNIQUE-BUCKET-NAME"
    terraform apply -var="bucket_name=YOUR-UNIQUE-BUCKET-NAME"

### Phase 2 — Migrate state to S3

1. Create backend.tf with the same bucket name.
2. Run:

    terraform init -migrate-state

3. Confirm migration with yes.
4. Check:

    terraform state list
    terraform state pull

### Verification

    terraform validate
    terraform plan -var="bucket_name=YOUR-UNIQUE-BUCKET-NAME"
    terraform output

The plan should show no changes after successful migration.

## Destroy infrastructure

Only destroy infrastructure when it is no longer needed and the assignment has been checked.

1. Temporarily move backend.tf:

    mv backend.tf backend.tf.disabled

2. Migrate state back to local storage:

    terraform init -migrate-state

3. Confirm migration and check state:

    terraform state list
    terraform state pull > terraform.tfstate.backup-manual

4. Destroy resources:

    terraform destroy -var="bucket_name=YOUR-UNIQUE-BUCKET-NAME"

5. Confirm the destroy operation.

6. Restore backend.tf for submission:

    mv backend.tf.disabled backend.tf

Note:
The S3 bucket uses force_destroy = true for this educational project.
This allows Terraform to delete the bucket including object versions and delete markers.

Three NAT Gateways incur AWS charges. Do not leave them running unnecessarily.

After destroying the infrastructure, backend.tf refers to a bucket that no longer exists.
Recreate the infrastructure before running terraform init with this backend configuration again.
