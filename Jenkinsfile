
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        AWS_DEFAULT_REGION = credentials('aws-region')
        AWS_ACCOUNT_ID = ''
        IMAGE_TAG = ''
        EC2_USER = 'ubuntu'
        APP_DIR = '/opt/aws-microservices'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Validate and Test') {
            steps {
                powershell '''
                    $ErrorActionPreference = "Stop"

                    foreach ($svc in @("user-service", "product-service", "order-service")) {
                        Write-Host "Testing $svc"

                        $venv = ".venv-$svc"
                        python -m venv $venv
                        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

                        $python = Join-Path $venv "Scripts\\python.exe"

                        & $python -m pip install -q -r "services/$svc/requirements.txt" pytest
                        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

                        Push-Location "services/$svc"
                        try {
                            & $python -m pytest -q
                            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
                        }
                        finally {
                            Pop-Location
                        }
                    }

                    docker compose config -q
                    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
                '''
            }
        }

        stage('Resolve AWS and Image Tags') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-ci'
                ]]) {
                    powershell '''
                        $ErrorActionPreference = "Stop"

                        $account = aws sts get-caller-identity --query Account --output text
                        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

                        Set-Content -Path ".aws-account-id" -Value $account -NoNewline

                        $tag = $env:GIT_COMMIT.Substring(0, 12)
                        Set-Content -Path ".image-tag" -Value $tag -NoNewline

                        foreach ($svc in @("user-service", "product-service", "order-service")) {
                            aws ecr describe-repositories --repository-names $svc --region $env:AWS_DEFAULT_REGION
                            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
                        }
                    '''
                }

                script {
                    env.AWS_ACCOUNT_ID = readFile('.aws-account-id').trim()
                    env.IMAGE_TAG = readFile('.image-tag').trim()
                }
            }
        }

        stage('Build and Push to ECR') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-ci'
                ]]) {
                    powershell '''
                        $ErrorActionPreference = "Stop"

                        $registry = "$env:AWS_ACCOUNT_ID.dkr.ecr.$env:AWS_DEFAULT_REGION.amazonaws.com"

                        aws ecr get-login-password --region $env:AWS_DEFAULT_REGION |
                            docker login --username AWS --password-stdin $registry

                        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

                        foreach ($svc in @("user-service", "product-service", "order-service")) {
                            Write-Host "Building $svc"

                            docker build -t "$registry/$svc`:$env:IMAGE_TAG" "services/$svc"
                            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

                            docker push "$registry/$svc`:$env:IMAGE_TAG"
                            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
                        }
                    '''
                }
            }
        }

        stage('Deploy to EC2') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'ec2-ssh-key',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    ),
                    string(
                        credentialsId: 'ec2-host',
                        variable: 'EC2_HOST'
                    ),
                    string(
                        credentialsId: 'grafana-admin-password',
                        variable: 'GRAFANA_PASSWORD'
                    )
                ]) {
                    powershell '''
                        $ErrorActionPreference = "Stop"

                        $registry = "$env:AWS_ACCOUNT_ID.dkr.ecr.$env:AWS_DEFAULT_REGION.amazonaws.com"

                        $content = @"
AWS_REGION=$env:AWS_DEFAULT_REGION
AWS_ACCOUNT_ID=$env:AWS_ACCOUNT_ID
USER_IMAGE=$registry/user-service`:$env:IMAGE_TAG
PRODUCT_IMAGE=$registry/product-service`:$env:IMAGE_TAG
ORDER_IMAGE=$registry/order-service`:$env:IMAGE_TAG
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=$env:GRAFANA_PASSWORD
"@

                        $envFile = Join-Path $PWD ".env.deploy"
                        [System.IO.File]::WriteAllText(
                            $envFile,
                            $content,
                            [System.Text.UTF8Encoding]::new($false)
                        )

                        $sshOptions = @("-i", $env:SSH_KEY, "-o", "StrictHostKeyChecking=accept-new")
                        $remote = "$env:SSH_USER@$env:EC2_HOST"

                        ssh @sshOptions $remote "sudo mkdir -p $env:APP_DIR/nginx $env:APP_DIR/monitoring/grafana/provisioning/datasources $env:APP_DIR/scripts && sudo chown -R ubuntu:ubuntu $env:APP_DIR"
                        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

                        scp @sshOptions "docker-compose.yml" "${remote}:$env:APP_DIR/"
                        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

                        scp @sshOptions ".env.deploy" "${remote}:$env:APP_DIR/.env.deploy"
                        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

                        scp @sshOptions "nginx/nginx.conf" "${remote}:$env:APP_DIR/nginx/nginx.conf"
                        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

                        scp @sshOptions "monitoring/prometheus.yml" "${remote}:$env:APP_DIR/monitoring/prometheus.yml"
                        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

                        scp @sshOptions "monitoring/grafana/provisioning/datasources/prometheus.yml" "${remote}:$env:APP_DIR/monitoring/grafana/provisioning/datasources/prometheus.yml"
                        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

                        scp @sshOptions "scripts/deploy-remote.sh" "${remote}:$env:APP_DIR/scripts/deploy-remote.sh"
                        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

                        $deployCommand = "mv $env:APP_DIR/.env.deploy $env:APP_DIR/.env && cd $env:APP_DIR && AWS_REGION=$env:AWS_DEFAULT_REGION AWS_ACCOUNT_ID=$env:AWS_ACCOUNT_ID bash scripts/deploy-remote.sh"

                        ssh @sshOptions $remote $deployCommand
                        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

                        ssh @sshOptions $remote "cd $env:APP_DIR && docker compose ps"
                        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

                        $healthUrl = "http://$env:EC2_HOST/health"
                        $healthy = $false

                        for ($i = 1; $i -le 10; $i++) {
                            try {
                                Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 10
                                $healthy = $true
                                break
                            }
                            catch {
                                Write-Host "Health check attempt $i failed. Retrying..."
                                Start-Sleep -Seconds 5
                            }
                        }

                        if (-not $healthy) {
                            throw "EC2 application health check failed: $healthUrl"
                        }

                        Remove-Item ".env.deploy" -Force -ErrorAction SilentlyContinue
                    '''
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: '.image-tag,.aws-account-id', allowEmptyArchive: true
        }

        success {
            echo 'Build, image push and deployment completed.'
        }

        failure {
            echo 'Pipeline failed. Review stage logs.'
        }
    }
}
