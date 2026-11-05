pipeline {
  agent any
  options { timestamps(); disableConcurrentBuilds() }
  environment {
    AWS_DEFAULT_REGION = credentials('aws-region')
    AWS_ACCOUNT_ID = ''
    IMAGE_TAG = ''
    EC2_USER = 'ubuntu'
    APP_DIR = '/opt/aws-microservices'
  }
  stages {
    stage('Checkout') {
      steps { checkout scm }
    }
    stage('Validate and Test') {
      steps {
        sh '''
          set -e
          for svc in user-service product-service order-service; do
            python3 -m venv "/tmp/venv-$svc"
            "/tmp/venv-$svc/bin/pip" install -q -r "services/$svc/requirements.txt" pytest
            (cd "services/$svc" && "/tmp/venv-$svc/bin/pytest" -q)
          done
          docker compose config -q
        '''
      }
    }
    stage('Resolve AWS and Image Tags') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-ci']]) {
          sh '''
            set -e
            ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
            echo "$ACCOUNT" > .aws-account-id
            echo "$GIT_COMMIT" | cut -c1-12 > .image-tag
            for svc in user-service product-service order-service; do
              aws ecr describe-repositories --repository-names "$svc" --region "$AWS_DEFAULT_REGION" >/dev/null
            done
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
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-ci']]) {
          sh '''
            set -e
            REGISTRY="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com"
            aws ecr get-login-password --region "$AWS_DEFAULT_REGION" | docker login --username AWS --password-stdin "$REGISTRY"
            for svc in user-service product-service order-service; do
              docker build -t "$REGISTRY/$svc:$IMAGE_TAG" "services/$svc"
              docker push "$REGISTRY/$svc:$IMAGE_TAG"
            done
          '''
        }
      }
    }
    stage('Deploy to EC2') {
      steps {
        withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER'),
                         string(credentialsId: 'ec2-host', variable: 'EC2_HOST'),
                         string(credentialsId: 'grafana-admin-password', variable: 'GRAFANA_PASSWORD')]) {
          sh '''
            set -e
            REGISTRY="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com"
            cat > .env.deploy <<EOF
            AWS_REGION=$AWS_DEFAULT_REGION
            AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID
            USER_IMAGE=$REGISTRY/user-service:$IMAGE_TAG
            PRODUCT_IMAGE=$REGISTRY/product-service:$IMAGE_TAG
            ORDER_IMAGE=$REGISTRY/order-service:$IMAGE_TAG
            GRAFANA_ADMIN_USER=admin
            GRAFANA_ADMIN_PASSWORD=$GRAFANA_PASSWORD
            EOF
            chmod 600 .env.deploy
            ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "$SSH_USER@$EC2_HOST" 'sudo mkdir -p /opt/aws-microservices/nginx /opt/aws-microservices/monitoring/grafana/provisioning/datasources && sudo chown -R ubuntu:ubuntu /opt/aws-microservices'
            scp -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new docker-compose.yml .env.deploy "$SSH_USER@$EC2_HOST:/opt/aws-microservices/"
            scp -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new nginx/nginx.conf "$SSH_USER@$EC2_HOST:/opt/aws-microservices/nginx/nginx.conf"
            scp -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new monitoring/prometheus.yml "$SSH_USER@$EC2_HOST:/opt/aws-microservices/monitoring/prometheus.yml"
            scp -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new monitoring/grafana/provisioning/datasources/prometheus.yml "$SSH_USER@$EC2_HOST:/opt/aws-microservices/monitoring/grafana/provisioning/datasources/prometheus.yml"
            ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "$SSH_USER@$EC2_HOST" 'mv /opt/aws-microservices/.env.deploy /opt/aws-microservices/.env && cd /opt/aws-microservices && AWS_REGION='"$AWS_DEFAULT_REGION"' AWS_ACCOUNT_ID='"$AWS_ACCOUNT_ID"' bash -s' < scripts/deploy-remote.sh
            ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "$SSH_USER@$EC2_HOST" 'cd /opt/aws-microservices && docker compose ps'
            curl --fail --retry 10 --retry-delay 5 "http://$EC2_HOST/health"
          '''
        }
      }
    }
  }
  post {
    always { archiveArtifacts artifacts: '.image-tag,.aws-account-id', allowEmptyArchive: true }
    success { echo 'Build, image push and deployment completed.' }
    failure { echo 'Pipeline failed. Review stage logs; the previous running containers are not intentionally removed before new images are pulled.' }
  }
}
