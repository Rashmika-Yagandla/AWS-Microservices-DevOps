# Implementation Guide — AWS Microservices CI/CD

## 1. Understand the application
The sample contains User, Product and Order services. Each service has its own source folder, Dockerfile, dependency file, test and `/health` endpoint. For the trainer's application, inspect its README, runtime, build command, port, environment variables, API routes and health endpoint. Replace only the sample service code and update Compose/Nginx/test configuration to match.

## 2. GitHub workflow
1. Create a private repository named `AWS-Microservices-DevOps`.
2. Push the initial code to `main`.
3. Create `develop` for integration work and `release` for approved releases.
4. Use feature branches such as `feature/nginx-routing`; open pull requests into `develop`.
5. Require review and passing checks before merging. Merge approved release changes into `release` and then `main`.
6. Add `.gitignore`; never commit `.env`, access keys, PEM files or Terraform state.
7. Configure GitHub webhook to `https://<secure-jenkins-url>/github-webhook/`, enable push and pull-request events, and test delivery. If Jenkins is not internet-reachable, use secure polling or a private network integration instead.

## 3. Prepare AWS
1. Choose a region, for example `ap-south-1`.
2. Create/download an EC2 key pair in the same region.
3. Find your public IP and set `allowed_ssh_cidr` to `x.x.x.x/32`.
4. Configure AWS CLI credentials locally for Terraform with an identity allowed to create EC2, IAM role/profile, security group and ECR resources. Prefer an IAM Identity Center profile.
5. Set an AWS Budget alert before provisioning.

## 4. Provision with Terraform
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit key_pair_name and allowed_ssh_cidr
terraform fmt -recursive
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output
```
Save the public IP and ECR URLs. Do not share state files. For team/production use, configure an encrypted S3 backend with versioning and state locking before the first `terraform init`; do not casually move or commit local state.

## 5. Prepare Jenkins
Install Jenkins on an existing workstation where possible. Install Pipeline, Git, GitHub integration and SSH Agent plugins. Ensure the Jenkins agent can run Docker, AWS CLI and Python 3. Add:
- `aws-ci`: AWS credentials with least-privilege ECR push access to exactly the three repositories and required `ecr:GetAuthorizationToken`.
- `ec2-ssh-key`: SSH private key for the EC2 key pair.
- `ec2-host`: secret text containing EC2 public IP/DNS.
- `grafana-admin-password`: secret text with a strong password.
- `aws-region`: secret text with the selected region (or edit the Jenkinsfile environment value).
Create a Pipeline-from-SCM job. The sample Jenkinsfile uses the AWS credentials binding plugin; verify it is installed and credential type is AWS credentials.

## 6. Deploy and verify
Run the Jenkins job. It checks out code, runs unit tests, validates Compose, builds three commit-tagged images, pushes them to ECR and deploys via SSH. On EC2:
```bash
cd /opt/aws-microservices
docker compose ps
docker compose logs --tail=100
curl -i http://localhost/health
curl -i http://localhost/api/users/health
curl -i http://localhost/api/products/health
curl -i http://localhost/api/orders/health
```
From your browser open `http://<EC2_PUBLIC_IP>`.

## 7. Monitoring
Open an SSH tunnel:
```bash
ssh -i <key.pem> -L 3000:127.0.0.1:3000 -L 9090:127.0.0.1:9090 ubuntu@<EC2_PUBLIC_IP>
```
Open Grafana `http://localhost:3000`, sign in with the configured admin password, and confirm the Prometheus datasource. Open Prometheus `http://localhost:9090/targets`; confirm Prometheus, Node Exporter and cAdvisor targets are UP. Import Grafana dashboard 1860 for Node Exporter metrics, then add container panels using cAdvisor metrics. Capture CPU, memory, filesystem and target availability screenshots.

## 8. Troubleshooting exercises
- Stop a service: `docker compose stop user-service`. Observe Nginx/API failure and Prometheus/cAdvisor changes. Restore: `docker compose start user-service`.
- View logs: `docker compose logs --tail=100 user-service nginx`.
- Check health: `docker inspect --format='{{json .State.Health}}' $(docker compose ps -q user-service)`.
- Check host: `free -h`, `df -h`, `top`, `docker stats`.
- If ECR pull fails, verify EC2 instance profile, region, account ID, repository name and image tag.
- If SSH fails, verify key permissions (`chmod 400 key.pem`), key pair, host, and security-group CIDR.
- If Nginx returns 502, check service health, container DNS names, Compose network and upstream ports.

## 9. Rollback
Keep the previous image tag. Update `.env` on EC2 to the previous three image tags, then run:
```bash
docker compose pull
docker compose up -d
docker compose ps
```
Re-run the health checks. A production pipeline should record the last-known-good release and make rollback a controlled Jenkins parameterized stage.

## 10. Cleanup
After evidence collection:
```bash
cd terraform
terraform destroy
```
Confirm the plan before approval. This configuration force-deletes ECR repositories and their images. Remove any separately created resources and credentials that are no longer required.
