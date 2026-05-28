# Deployment

This folder contains the infrastructure-as-code to provision a VM pre-configured with Docker and Docker Compose, ready to host Traefik and your applications.

Two providers are supported:

| Provider | Tool | Free tier |
|---|---|---|
| AWS | CloudFormation | t2.micro — 750 hrs/month, **12 months only** |
| OCI | Terraform | VM.Standard.A1.Flex (ARM) — **always free** |

---

## Folder structure

```
deploy/
  aws/
    cloudformation.yaml       # EC2 + Security Group + Elastic IP
  oci/
    providers.tf              # Terraform provider and S3 backend config
    variables.tf              # All input variables
    main.tf                   # VCN, subnet, compute instance, reserved IP
    outputs.tf                # Instance ID, public IP, SSH command
    terraform.tfvars.example  # Template for your local variables file
```

---

## AWS (CloudFormation)

### Resources created

- EC2 instance (Amazon Linux 2023, Docker + Docker Compose pre-installed)
- Security Group (ports 80, 443 open to all; port 22 restricted to your IP)
- Elastic IP

### Manual deploy

1. Go to AWS Console → **CloudFormation** → **Create stack** → **With new resources**
2. Upload `aws/cloudformation.yaml`
3. Fill in the parameters and create the stack
4. Once complete, find the public IP in the **Outputs** tab

### Automated deploy (GitHub Actions)

Pushing any change to `deploy/aws/` on `main` automatically deploys the stack via `.github/workflows/deploy-aws.yml`.

#### One-time AWS setup

**1. Add GitHub as an OIDC Identity Provider**

IAM → **Identity providers** → **Add provider**:
- Provider type: **OpenID Connect**
- Provider URL: `https://token.actions.githubusercontent.com` → click **Get thumbprint**
- Audience: `sts.amazonaws.com`

Only needs to be done once per AWS account.

**2. Create the IAM Role**

IAM → **Roles** → **Create role**:
- Trusted entity: **Web identity**
- Identity provider: `token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`
- Name it something like `github-actions-traefik-deploy`

After creation, open the role → **Trust relationships** → **Edit trust policy** and replace with:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:<GITHUB_USERNAME>/<REPO_NAME>:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

Replace `<ACCOUNT_ID>`, `<GITHUB_USERNAME>`, and `<REPO_NAME>` with your values.

Then → **Permissions** → **Add permissions** → **Create inline policy** → **JSON**:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudFormation",
      "Effect": "Allow",
      "Action": [
        "cloudformation:CreateStack",
        "cloudformation:UpdateStack",
        "cloudformation:DescribeStacks",
        "cloudformation:DescribeStackEvents",
        "cloudformation:DescribeStackResources",
        "cloudformation:GetTemplate",
        "cloudformation:ValidateTemplate",
        "cloudformation:CreateChangeSet",
        "cloudformation:ExecuteChangeSet",
        "cloudformation:DescribeChangeSet",
        "cloudformation:DeleteChangeSet"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EC2",
      "Effect": "Allow",
      "Action": [
        "ec2:RunInstances",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus",
        "ec2:TerminateInstances",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:DescribeSecurityGroups",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:AllocateAddress",
        "ec2:ReleaseAddress",
        "ec2:AssociateAddress",
        "ec2:DisassociateAddress",
        "ec2:DescribeAddresses",
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeKeyPairs",
        "ec2:CreateTags",
        "ec2:DescribeImages"
      ],
      "Resource": "*"
    },
    {
      "Sid": "SSMForAmiLookup",
      "Effect": "Allow",
      "Action": ["ssm:GetParameter", "ssm:GetParameters"],
      "Resource": "arn:aws:ssm:*::parameter/aws/service/ami-amazon-linux-latest/*"
    },
    {
      "Sid": "S3TerraformState",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::<TF_STATE_BUCKET>",
        "arn:aws:s3:::<TF_STATE_BUCKET>/projects/deployment/OCI/*"
      ]
    }
  ]
}
```

Replace `<TF_STATE_BUCKET>` with the name of the S3 bucket you'll use for Terraform state.

> The S3 permission block is only needed if you're also using the OCI deployment, since it stores its Terraform state in this same AWS role.

**3. Add GitHub Secrets and Variables**

Go to your GitHub repo → **Settings** → **Secrets and variables** → **Actions**.

Secrets (masked in logs):

| Name | Value |
|---|---|
| `AWS_ROLE_ARN` | ARN of the role created above |
| `CF_KEY_NAME` | Name of your EC2 key pair |
| `CF_SSH_LOCATION` | Your IP in CIDR form, e.g. `203.0.113.5/32` |

Variables (plain config, visible in logs):

| Name | Example |
|---|---|
| `AWS_REGION` | `us-east-1` |
| `STACK_NAME` | `traefik-vm` |
| `CF_VPC_ID` | `vpc-0abc123def456` |
| `CF_SUBNET_ID` | `subnet-0abc123def456` |
| `CF_AVAILABILITY_ZONE` | `us-east-1a` |
| `CF_OWNER` | `admin` |

---

## OCI (Terraform)

### Resources created

- VCN + Internet Gateway + Route Table + Security List (equivalent to VPC)
- Subnet
- Compute instance (Oracle Linux 9, ARM, Docker + Docker Compose pre-installed)
- Reserved public IP (equivalent to Elastic IP)

### Terraform state

Terraform state is stored remotely in an S3 bucket at:
```
s3://<TF_STATE_BUCKET>/projects/deployment/OCI/terraform.tfstate
```

This uses the same IAM role as the AWS deployment via OIDC — no extra credentials needed.

### Manual deploy

Copy the example vars file and fill it in:
```bash
cd deploy/oci
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with your values
```

Then run:
```bash
terraform init \
  -backend-config="bucket=YOUR_BUCKET" \
  -backend-config="key=projects/deployment/OCI/terraform.tfstate" \
  -backend-config="region=us-east-1"

terraform plan
terraform apply
```

### Automated deploy (GitHub Actions)

Pushing any change to `deploy/oci/` on `main` automatically deploys the stack via `.github/workflows/deploy-oci.yml`.

Uses the same IAM role as the AWS workflow (OIDC setup above) to access S3 for state storage.

**Additional secrets required:**

| Name | Value |
|---|---|
| `TF_STATE_BUCKET` | S3 bucket name for Terraform state |
| `OCI_TENANCY_OCID` | From OCI Console → Profile |
| `OCI_USER_OCID` | From OCI Console → Profile |
| `OCI_FINGERPRINT` | From your API key in OCI Console |
| `OCI_PRIVATE_KEY` | Contents of your `.pem` API key file |
| `OCI_COMPARTMENT_OCID` | Target compartment OCID |
| `OCI_AVAILABILITY_DOMAIN` | e.g. `Uocm:US-ASHBURN-AD-1` |
| `OCI_SSH_PUBLIC_KEY` | Contents of your `~/.ssh/id_rsa.pub` |
| `OCI_SSH_CIDR` | Your IP in CIDR form, e.g. `203.0.113.5/32` |

Variables:

| Name | Example |
|---|---|
| `OCI_REGION` | `us-ashburn-1` |

---

## Post-deployment

SSH into the instance:

```bash
# AWS
ssh -i your-key.pem ec2-user@<PublicIP>

# OCI
ssh opc@<PublicIP>
```

Clone this repo and start Traefik:

```bash
cd ~/app
git clone <your-repo-url> .
cp .env.example .env
# edit .env with your DOMAIN and ACME_EMAIL
docker compose up -d
```
