# Terraform VCS-Driven Workflow

Sample Terraform project for a GitHub-driven AWS deployment flow using **HCP Terraform**, **OIDC-based AWS authentication**, and **OPA policy enforcement**.

This repository demonstrates a secure Infrastructure as Code workflow where infrastructure changes are reviewed through Git, planned remotely, and blocked by policy before apply if they violate security guardrails.

> This is a reference implementation and sample setup. Some values in this README are illustrative and should be adapted to your own AWS account, HCP workspace, and policy configuration.

---

## Architecture

![Terraform VCS-Driven Workflow](docs/images/terraform-vcs-workflow.png)

### Workflow

```text
Developer / VS Code
        |
        | git commit & push
        v
GitHub Repository
        |
        | VCS trigger
        v
HCP Terraform
        |
        +---- Terraform Plan
        |
        +---- OPA Policy Check
        |          |
        |          +---- PASS ----> Terraform Apply
        |          |
        |          +---- FAIL ----> Apply Blocked
        |
        v
AWS
├── VPC
├── Subnet
├── Internet Gateway
├── Route Table
├── Security Group
└── EC2
```

How it works:

1. Terraform code is authored locally.
2. Changes are committed and pushed to GitHub.
3. GitHub triggers a run in HCP Terraform.
4. HCP Terraform authenticates to AWS through OIDC.
5. Terraform creates a plan.
6. OPA evaluates the plan against policy rules.
7. If the policy fails, apply is blocked.
8. If the policy passes, the run can proceed to apply.

---

## Repository structure

```text
terraform-vcs-driven-workflow/
├── docs/
│   └── images/
│       ├── terraform-vcs-workflow.png
│       ├── opa-pass.png
│       └── opa-fail.png
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
│   ├── deny-public-ingress.rego
│   └── restrict-instance-type.rego
├── .gitignore
├── .terraform.lock.hcl
├── main.tf
├── providers.tf
├── variables.tf
├── README.md
└── .terraform/   # local Terraform cache (if created)
```

This project is split into reusable Terraform modules for:

- networking
- security groups
- EC2 compute

---

## Prerequisites

Before using the repo in a real environment, make sure you have:

- Terraform installed locally
- An AWS account and target region
- An HCP Terraform workspace connected to GitHub
- OIDC trust configured between HCP Terraform and AWS
- A policy set or mandatory policy in HCP Terraform

---

## Quick start

1. Initialize the Terraform working directory:

```bash
terraform init
```

2. Review the plan:

```bash
terraform plan
```

3. Create or update your local `terraform.tfvars` values for your environment.

4. Push the repo to GitHub and trigger the HCP Terraform run.

5. Confirm the plan passes the required OPA policy checks before apply.

---

## Terraform modules

### Network module

The `network` module provisions:

- VPC
- public subnet
- internet gateway
- route table
- route table association

Example values:

```hcl
vpc_cidr           = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
availability_zone  = "ap-northeast-1a"
```

### Security group module

The `security-group` module creates the EC2 security group and allows inbound traffic from a configurable CIDR.

Example:

```hcl
allowed_http_cidr_block = "10.0.0.0/8"
```

### Compute module

The `compute` module provisions the EC2 instance using a dynamically discovered Amazon Linux 2023 AMI.

Example:

```hcl
instance_type = "t3.micro"
```

---

## Security model

### OIDC authentication

This project avoids static AWS credentials. Instead, HCP Terraform uses **OIDC** to authenticate to AWS with separate roles for Terraform plan and apply operations.

Typical environment variables:

```text
TFC_AWS_PROVIDER_AUTH=true
TFC_AWS_PLAN_ROLE_ARN=arn:aws:iam::123456789012:role/hcp-terraform-plan-role
TFC_AWS_APPLY_ROLE_ARN=arn:aws:iam::123456789012:role/hcp-terraform-apply-role
```

No `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` is required.

### OPA policy enforcement

The repository includes a policy to block public ingress from `0.0.0.0/0`.

The actual policy is in [policies/deny-public-ingress.rego](policies/deny-public-ingress.rego):

```rego
package terraform.security.public_ingress

import input.plan as plan

deny := [msg |
    resource := plan.resource_changes[_]
    resource.type == "aws_vpc_security_group_ingress_rule"
    resource.change.after.cidr_ipv4 == "0.0.0.0/0"

    msg := sprintf(
        "%s allows inbound traffic from 0.0.0.0/0. Public ingress is not allowed.",
        [resource.address]
    )
]
```

The HCP Terraform query used to evaluate it is:

```text
data.terraform.security.public_ingress.deny
```

This means even a valid Terraform plan can be rejected before apply if it violates the required policy.

> Example pass result: ![OPA Policy Passed](docs/images/opa-pass.png)
>
> Example fail result: ![OPA Policy Failed](docs/images/opa-fail.png)

---

## Example configuration

Example `terraform.tfvars`:

```hcl
project_name      = "terraform-vcs"
aws_region        = "ap-northeast-1"
availability_zone = "ap-northeast-1a"

vpc_cidr           = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"

instance_type = "t3.micro"

ssh_cidr_block          = null
allowed_http_cidr_block = "10.0.0.0/8"
```

---

## HCP Terraform workflow

This repo is designed for a remote execution model in HCP Terraform.

```text
git push
   |
   v
GitHub
   |
   v
HCP Terraform
   |
   +--> Plan
   |
   +--> OPA check
   |
   +--> Apply (if allowed)
   |
   v
AWS
```

The intent is to keep Terraform state and execution logic in a controlled remote workflow rather than running production applies from a developer machine.

---

## Security notes

This project demonstrates several important controls:

- Git-based change management
- remote Terraform execution
- OIDC-based AWS authentication
- separate plan/apply IAM roles
- least-privilege access
- mandatory policy enforcement
- blocked public ingress
- modular infrastructure design

There is also a placeholder policy file for instance-type restrictions in [policies/restrict-instance-type.rego](policies/restrict-instance-type.rego), which can be completed and enabled if you want an additional EC2 guardrail.

---

## Summary

This repository is a practical example of a secure Terraform delivery workflow:

```text
Code -> GitHub -> HCP Terraform -> Plan -> OPA -> Apply -> AWS
```

The main idea is simple:

> A valid Terraform plan is not automatically an approved infrastructure change.

Policy checks are used to decide whether a change is allowed to reach AWS.

Terraform determines **what will change**, while OPA determines **whether that change is allowed**.

Only infrastructure changes that satisfy the defined security policies are allowed to reach AWS.