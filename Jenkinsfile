pipeline {
    agent any
    environment{
        IMAGE_NAME = "calculator-app"
        AWS_ACCOUNT_ID = '992382545251'
        REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com"
        ECR_REPO = "${REGISTRY}/${IMAGE_NAME}"
        AWS_REGION = 'us-east-1'
        IMAGE_TAG = 'latest' // for CD --> overridden for PR
        EC2_PUBLIC_IP = '184.73.135.135' 

    }
    //CI stages
    stages{
        stage('Checkout'){
            steps{
                checkout scm
            }
        }
        stage('CI: build and test'){
            when {branch 'PR-*'}
            steps{
                script{
                    def imageTag = "pr-${env.CHANGE_ID}-${BUILD_NUMBER}" // PR specific tag
		    env.IMAGE_TAG = imageTag
                }
                sh "docker build -t ${ECR_REPO}:${IMAGE_TAG} ."
                sh "docker run --rm -e PYTHONPATH=/app ${ECR_REPO}:${IMAGE_TAG} pytest -q tests/test_calculator_logic.py"
                sh "docker run --rm -e PYTHONPATH=/app ${ECR_REPO}:${IMAGE_TAG} pytest -q tests/test_calculator_app_integration.py"

            }
        }

        //CD stages
        stage('CD: Build & Test') {
            when {branch 'master'}
            steps {
                sh "docker build -t ${ECR_REPO}:${IMAGE_TAG} ."
                sh "docker run --rm -e PYTHONPATH=/app ${ECR_REPO}:${IMAGE_TAG} pytest -q tests/test_calculator_logic.py"
                sh "docker run --rm -e PYTHONPATH=/app ${ECR_REPO}:${IMAGE_TAG} pytest -q tests/test_calculator_app_integration.py"
            }
        }
        
        // Push to ECR
        stage('Push to ECR') {
            steps {
                script {
                    // Login to AWS ECR
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REGISTRY}"
		    sh "docker build -t ${ECR_REPO}:${IMAGE_TAG} ."
		    sh "docker images"
		    sh "docker tag ${ECR_REPO}:${IMAGE_TAG} ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
                    sh "docker push ${ECR_REPO}:${IMAGE_TAG}"
                }
            }
        }

        // CD Deploy to EC2 (only on master)
        stage('CD: Deploy to Production EC2') {
            when {branch 'master'}
            steps {
                script {
                    def sshKeyPath = "/root/.ssh/annaj2.pem"
                    // SSH into EC2 to pull and run the latest image
                    sh """
                    ssh -i ${sshKeyPath} -o StrictHostKeyChecking=no ubuntu@${EC2_PUBLIC_IP} 'docker pull ${ECR_REPO}:${IMAGE_TAG} && docker run -d -p 5000:5000 ${ECR_REPO}:${IMAGE_TAG}'
                    """
                }
            }
        }

        // Health Check (only on master after deploy)
        stage('CD: Health Check') {
            when {branch 'master'}
            steps {
                script {
                    def healthCheckResponse = sh(script: "curl -fsS http://${EC2_PUBLIC_IP}:5000/health", returnStatus: true)
                    if (healthCheckResponse != 0) {
                        error "Health check failed!"
                    }
                }
            }
        }
    }
}

        
