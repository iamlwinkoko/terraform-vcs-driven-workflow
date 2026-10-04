# Terraform VCS-Driven Workflow

A VCS-driven Infrastructure as Code project using GitHub, HCP Terraform,
AWS, OIDC-based dynamic credentials, and Open Policy Agent (OPA) policy
enforcement.

## Architecture

``` text
Developer / VS Code
        |
        | git push
        v
GitHub Repository
        |
        | VCS-triggered run
        v
HCP Terraform
        |
        +--> Terraform Plan
        |
        +--> OPA Policy Check
        |       |
        |       +--> PASS -> Terraform Apply
        |       |
        |       +--> FAIL -> Apply blocked
        |
        v
AWS
  |- VPC / networking
  |- Security Group
  `- EC2
```

The HCP Terraform workspace uses AWS workload identity (OIDC) instead of
long-lived AWS access keys.

## Project Structure

``` text
terraform-vcs-driven-workflow/
├── modules/
│   ├── compute/
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   ├── network/
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   └── security-group/
│       ├── main.tf
│       ├── outputs.tf
│       └── variables.tf
├── policies/
├── .gitignore
├── .terraform.lock.hcl
├── main.tf
├── providers.tf
├── terraform.tfvars
├── variables.tf
└── README.md
```

> OPA policies are currently configured in the HCP Terraform UI. The
> local `policies/` directory can be used to keep a reference copy of
> policy code.

## Workflow

1.  Terraform code is developed locally in VS Code.
2.  Changes are committed and pushed to GitHub.
3.  The GitHub VCS integration triggers an HCP Terraform run.
4.  HCP Terraform assumes the AWS **plan role** using OIDC and generates
    the Terraform plan.
5.  HCP Terraform evaluates the plan with the configured **OPA policy
    set**.
6.  If a mandatory policy fails, the run stops and apply is blocked.
7.  If all mandatory policies pass, HCP Terraform can proceed to apply.
8.  During apply, HCP Terraform assumes the AWS **apply role** and
    creates, updates, or deletes the required AWS resources.

## AWS Authentication

No static AWS access keys are stored in Terraform.

HCP Terraform uses AWS dynamic provider credentials through OIDC.

### Plan Role

``` text
arn:aws:iam::541341196654:role/hcp-terraform-plan-role
```

Purpose:

-   Used during `terraform plan`
-   Read/Describe permissions required to inspect AWS resources
-   Trust policy is restricted to the HCP Terraform plan run phase

### Apply Role

``` text
arn:aws:iam::541341196654:role/hcp-terraform-apply-role
```

Purpose:

-   Used during `terraform apply`
-   Create/Update/Delete permissions required by the managed
    infrastructure
-   Trust policy is restricted to the HCP Terraform apply run phase

### HCP Terraform Environment Variables

``` text
TFC_AWS_PROVIDER_AUTH=true
TFC_AWS_PLAN_ROLE_ARN=arn:aws:iam::541341196654:role/hcp-terraform-plan-role
TFC_AWS_APPLY_ROLE_ARN=arn:aws:iam::541341196654:role/hcp-terraform-apply-role
```

## IAM Policies

The recommended least-privilege mapping is:

``` text
hcp-terraform-plan-role
    -> HCP-Terraform-Plan-Policy

hcp-terraform-apply-role
    -> HCP-Terraform-Apply-Policy
```

The plan policy should primarily contain read/describe permissions. The
apply policy should contain only the create, update, delete, and read
permissions required by this Terraform configuration.

> **Important:** Do not swap the plan and apply policies. The plan role
> should receive the Plan policy, and the apply role should receive the
> Apply policy.

## OPA Policy Enforcement

OPA policies are configured as mandatory policies in HCP Terraform.

### Public Ingress Guardrail

The security policy denies an AWS security group ingress rule when:

``` text
cidr_ipv4 == "0.0.0.0/0"
```

Example allowed configuration:

``` hcl
allowed_http_cidr_block = "10.0.0.0/8"
```

Expected result:

``` text
Terraform Plan -> OPA PASS -> Apply allowed
```

Example denied configuration:

``` hcl
allowed_http_cidr_block = "0.0.0.0/0"
```

Expected result:

``` text
Terraform Plan -> OPA FAIL -> Apply blocked
```

### EC2 Instance Type Guardrail

The project is designed to allow only:

``` text
t3.micro
```

An OPA rule can reject planned `aws_instance` resources whose
`instance_type` is not `t3.micro`.

## Terraform Configuration

AWS provider:

``` hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.67.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
```

Example values:

``` hcl
project_name      = "terraform-vcs"
aws_region        = "ap-northeast-1"
availability_zone = "ap-northeast-1a"

vpc_cidr           = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"

instance_type = "t3.micro"

allowed_http_cidr_block = "10.0.0.0/8"
```

## HCP Terraform

Workspace:

``` text
terraform-vcs-driven-workflow
```

Execution mode:

``` text
Remote
```

The HCP Terraform workspace is connected to the GitHub repository, so
pushes to the configured branch trigger Terraform runs automatically.

## Security Design

This project follows several Infrastructure as Code security practices:

-   No long-lived AWS access keys
-   AWS authentication through OIDC
-   Separate IAM roles for plan and apply
-   Least-privilege IAM permissions
-   Mandatory OPA policy enforcement before apply
-   Public `0.0.0.0/0` HTTP ingress blocked by policy
-   EC2 instance type restricted by policy
-   Terraform state managed remotely by HCP Terraform
-   Infrastructure changes initiated through Git/VCS

## Testing the OPA Policy

Test an allowed CIDR:

``` hcl
allowed_http_cidr_block = "10.0.0.0/8"
```

Commit and push:

``` bash
git add .
git commit -m "test: allow private HTTP ingress"
git push
```

The OPA policy should pass.

Then test the prohibited CIDR:

``` hcl
allowed_http_cidr_block = "0.0.0.0/0"
```

Commit and push again:

``` bash
git add .
git commit -m "test: verify OPA blocks public ingress"
git push
```

The Terraform plan may succeed, but the mandatory OPA policy should fail
and prevent the apply stage.

## Destroying Infrastructure

For this VCS-driven project, destroy managed infrastructure from the HCP
Terraform workspace so the operation uses the same remote state and AWS
dynamic credentials.

Review the destroy plan carefully before confirming the apply.

Destroying infrastructure removes the AWS resources managed by the
workspace. It does not require deleting the HCP Terraform workspace
itself.

## Technologies

-   Terraform
-   HCP Terraform
-   GitHub
-   AWS
-   AWS IAM
-   OIDC / Dynamic Provider Credentials
-   Open Policy Agent (OPA)
-   Rego

## Goal

The goal of this project is to demonstrate a secure VCS-driven Terraform
workflow where infrastructure changes are version controlled, planned
remotely, validated by policy, authenticated to AWS without static
credentials, and applied only after the required guardrails pass.
