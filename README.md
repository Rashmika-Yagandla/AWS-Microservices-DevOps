# AWS Microservices CI/CD, Deployment & Monitoring

A practical starter implementation for three microservices: **User Service**, **Product Service**, and **Order Service**. It uses Docker Compose, Nginx, Jenkins, Terraform, Amazon ECR, Prometheus, Node Exporter, cAdvisor, and Grafana.

> Important: this repository is a runnable reference implementation because the trainer's actual application repository, frameworks, ports, and API contracts were not supplied. Replace the sample service code and adjust ports/routes to match the actual three microservices before final evaluation.

## Architecture

- Jenkins runs on an existing workstation (recommended); it checks out this repository, tests, builds and pushes three versioned images to ECR.
- Terraform provisions one Ubuntu EC2 instance, three ECR repositories, a security group, an EC2 IAM role and instance profile.
- EC2 uses its instance role to authenticate to ECR and pull approved images.
- Docker Compose runs the three services, Nginx, Prometheus, Node Exporter, cAdvisor and Grafana.
- Public traffic enters through Nginx on port 80. Monitoring ports are not public; use an SSH tunnel.

## Repository layout

```text
AWS-Microservices-DevOps/
├── services/
│   ├── user-service/       # Flask sample service + Dockerfile + tests
│   ├── product-service/
│   └── order-service/
├── nginx/nginx.conf
├── monitoring/
│   ├── prometheus.yml
│   └── grafana/provisioning/datasources/prometheus.yml
├── terraform/
│   ├── versions.tf
│   ├── variables.tf
│   ├── main.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── scripts/
│   ├── deploy-remote.sh
│   └── health-check.sh
├── docker-compose.yml
├── docker-compose.local.yml
├── Jenkinsfile
├── .env.example
├── .gitignore
└── docs/
    └── implementation-guide.md
```

## Prerequisites

- GitHub repository and branch protection/pull-request workflow.
- AWS account, AWS CLI configured for Terraform, and an EC2 key pair.
- Terraform >= 1.6, Docker Engine + Compose plugin, Git.
- Jenkins on a workstation with Git, Docker, AWS CLI, SSH Agent plugin and Pipeline plugin.
- A Jenkins AWS credential (Access Key/Secret or approved federation) with permissions to push to the three ECR repositories and read deployment outputs.
- A Jenkins SSH private-key credential for the EC2 key pair. Do not commit keys, tokens, `.env` files, or Terraform state.

## Quick local run

```bash
cp .env.example .env
docker compose -f docker-compose.yml -f docker-compose.local.yml up --build -d
docker compose ps
curl http://localhost/health
curl http://localhost/api/users/health
curl http://localhost/api/products/health
curl http://localhost/api/orders/health
docker compose logs -f
```

Open `http://localhost`. Stop with `docker compose -f docker-compose.yml -f docker-compose.local.yml down`.

## AWS deployment overview

1. Create a GitHub repository and push this project to `main`.
2. Configure `terraform/terraform.tfvars` from the example. Set `allowed_ssh_cidr` to your public IP in `/32` form and choose an existing EC2 key pair.
3. From `terraform/`, run `terraform init`, `terraform fmt -check`, `terraform validate`, `terraform plan`, then `terraform apply`.
4. Record the EC2 public IP and three ECR repository URLs from Terraform outputs.
5. Add Jenkins credentials: `aws-ci` (AWS credentials) and `ec2-ssh-key` (SSH private key). Add Jenkins environment variables `AWS_DEFAULT_REGION`, `EC2_HOST`, `EC2_USER=ubuntu`, and `SSH_CREDENTIALS_ID=ec2-ssh-key`.
6. Configure GitHub webhook to `https://<your-jenkins-host>/github-webhook/` if Jenkins is reachable securely from GitHub. Otherwise use a secured reverse proxy or polling; do not expose Jenkins directly to the internet.
7. Create a Jenkins Pipeline job from SCM and point it to this repository's `Jenkinsfile`.
8. Run the pipeline. It tests, builds, tags with the Git commit, pushes images, transfers deployment files, and deploys remotely.
9. Verify the application and monitoring using the guide below.

## Monitoring access (private)

Prometheus and Grafana bind to EC2 loopback only. From your workstation:

```bash
ssh -i <key.pem> -L 3000:127.0.0.1:3000 -L 9090:127.0.0.1:9090 ubuntu@<EC2_PUBLIC_IP>
```

Then open Grafana at `http://localhost:3000` (default demo login `admin` / value of `GRAFANA_ADMIN_PASSWORD` in `.env`; change it before deployment) and Prometheus at `http://localhost:9090`.

Node Exporter metrics are scraped by Prometheus. cAdvisor exposes container metrics. Grafana datasource is provisioned automatically. Import dashboard ID **1860** (Node Exporter Full) or create panels for CPU, memory, disk and service availability. Do not expose Grafana/Prometheus ports in the EC2 security group.

## Security checklist

- Restrict SSH ingress to your trusted public IP (`x.x.x.x/32`).
- Only expose HTTP 80 for the demo; add HTTPS with a managed certificate/reverse proxy before production.
- Keep Jenkins private; use VPN or a secured reverse proxy with TLS and authentication.
- Use IAM roles on EC2 for ECR pull. Jenkins should have least-privilege ECR push permissions.
- Store secrets in Jenkins Credentials or AWS Secrets Manager/SSM Parameter Store. Never commit secrets.
- Rotate credentials and change Grafana's demo password.
- Enable AWS Budget alerts. ECR image retention/lifecycle policies are recommended.
- Terraform state may contain sensitive values. Use a remote encrypted S3 backend with locking for team use; local state is for a disposable demo only.

## Cleanup

After collecting evidence, run from `terraform/`:

```bash
terraform destroy
```

This removes the EC2 instance, ECR repositories and IAM/security resources created by this configuration. ECR repositories are configured to force-delete images during cleanup. Confirm no resources are needed before destroying. Also remove any manually created key pairs, budgets, snapshots, or Jenkins credentials separately.

## Evidence to capture

1. GitHub branches, pull request and webhook configuration.
2. Jenkins successful build with checkout/test/build/push/deploy stages.
3. Terraform plan/apply and outputs (mask account IDs if required).
4. Three ECR repositories with commit-tagged images.
5. EC2 `docker compose ps`, Nginx app response and service health endpoints.
6. Prometheus targets showing `UP`.
7. Grafana dashboard showing CPU, memory, disk and container/service metrics.
8. Failure simulation, logs, recovery and rollback demonstration.
