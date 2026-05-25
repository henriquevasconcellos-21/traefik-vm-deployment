# Deployment Instructions

This folder contains a CloudFormation template to deploy an EC2 instance pre-configured with Docker and Docker Compose, ready to host Traefik and your applications.

## Resources Created

- **EC2 Instance**: Amazon Linux 2023 with Docker and Docker Compose installed via UserData.
- **Security Group**: Allows inbound traffic on ports 80 (HTTP), 443 (HTTPS), and 22 (SSH).
- **Elastic IP**: Provides a stable public IP address for your server.

## Parameters

| Parameter | Default | Notes |
|---|---|---|
| `InstanceType` | `t2.micro` | Free Tier eligible |
| `KeyName` | — | Name of an existing EC2 Key Pair |
| `VpcId` | — | ID of your existing VPC |
| `SubnetId` | — | ID of a public subnet in your VPC |
| `SSHLocation` | — | Your IP in CIDR form, e.g. `1.2.3.4/32` |
| `LatestAmiId` | Latest AL2023 | Resolved automatically via SSM |

## Manual Deploy

1. Go to the AWS Console → **CloudFormation** → **Create stack** → **With new resources**
2. Upload `cloudformation.yaml`
3. Fill in the parameters and create the stack
4. Once complete, find the public IP in the **Outputs** tab

## Automated Deploy (GitHub Actions)

Pushing a change to `deploy/cloudformation.yaml` on `main` automatically deploys the stack via the workflow at `.github/workflows/deploy-cloudformation.yml`.

### One-time AWS setup

#### 1. Add GitHub as an OIDC Identity Provider

IAM → **Identity providers** → **Add provider**:
- Provider type: **OpenID Connect**
- Provider URL: `https://token.actions.githubusercontent.com` → click **Get thumbprint**
- Audience: `sts.amazonaws.com`

Only needs to be done once per AWS account.

#### 2. Create the IAM Role

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
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": "arn:aws:ssm:*::parameter/aws/service/ami-amazon-linux-latest/*"
    }
  ]
}
```

#### 3. Add GitHub Secrets and Variables

Go to your GitHub repo → **Settings** → **Secrets and variables** → **Actions**.

**Secrets** (masked in logs):

| Name | Value |
|---|---|
| `AWS_ROLE_ARN` | ARN of the role created above |
| `EC2_KEY_NAME` | Name of your EC2 key pair (not the `.pem` file) |
| `SSH_LOCATION` | Your IP in CIDR form, e.g. `203.0.113.5/32` |

**Variables** (plain config):

| Name | Example |
|---|---|
| `AWS_REGION` | `us-east-1` |
| `VPC_ID` | `vpc-0abc123def456` |
| `SUBNET_ID` | `subnet-0abc123def456` |
| `STACK_NAME` | `traefik-vm` |

## Post-Deployment

SSH into the instance:

```bash
ssh -i your-key.pem ec2-user@<PublicIP>
```

Clone this repo into the app directory:

```bash
cd /home/ec2-user/app
git clone <your-repo-url> .
```

Configure your `.env` file based on `.env.example`, then start Traefik:

```bash
docker compose up -d
```
