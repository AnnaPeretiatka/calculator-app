pipeline {
    agent any
    options {
        skipDefaultCheckout(true)
    }
    environment {
        IMAGE_NAME = "annacalc"
        AWS_ACCOUNT_ID = '992382545251'
        AWS_REGION = 'us-east-1'
        REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        ECR_REPO = "${REGISTRY}/${IMAGE_NAME}"
        IMAGE_TAG = 'latest' // default fallback, overwritten for PR/main
        PROD_IP = '107.23.11.231'
    }
    stages {
        stage('Cleanup') {
            steps {
                deleteDir()
            }
        }

        stage('Checkout') {
            steps {
                checkout([$class: 'GitSCM',
                          branches: [[name: 'main']],
                          userRemoteConfigs: [[
                              url: 'https://github.com/AnnaPeretiatka/calculator-app.git',
                              credentialsId: 'github-pat'
                          ]]])
            }
        }

        stage('CI: Build, Test, Push (PR)') {
            when { changeRequest() }
            agent {
                docker {
                    image 'docker:24-dind'
                    args '-v /var/run/docker.sock:/var/run/docker.sock'
                    reuseNode true
                }
            }
            steps {
                script { env.IMAGE_TAG = "pr-${env.CHANGE_ID}-${env.BUILD_NUMBER}" }
                // Build test image
                sh 'docker build --target test -t ${IMAGE_NAME}:${IMAGE_TAG}-test .'
                sh 'docker run --rm -e PYTHONPATH=/app ${IMAGE_NAME}:${IMAGE_TAG}-test'
                // Build prod image inside DinD
                sh 'docker build --target prod -t ${ECR_REPO}:${IMAGE_TAG} .'
            }
        }

	
        stage('Push PR Image to ECR') {
            when { changeRequest() }
            steps {
                script {
		    sh """
		        aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REGISTRY}
			docker push ${ECR_REPO}:${IMAGE_TAG}
		    """
		}
            }
        }

        stage('CD: Build, Test, Push, Deploy (main)') {
            when { branch 'main' }
            agent {
                docker {
                    image 'docker:24-dind'
                    args '-v /var/run/docker.sock:/var/run/docker.sock'
                    reuseNode true
                }
            }
            steps {
                script { env.IMAGE_TAG = "candidate-${env.SHORT_COMMIT ?: env.BUILD_NUMBER}" }
                
                // Build & test
                sh 'docker build --target test -t ${IMAGE_NAME}:${IMAGE_TAG}-test .'
                sh 'docker run --rm -e PYTHONPATH=/app ${IMAGE_NAME}:${IMAGE_TAG}-test'
                // Build prod image inside DinD
                sh 'docker build --target prod -t ${ECR_REPO}:${IMAGE_TAG} .'
            }
        }

        stage('Push to ECR & Deploy') {
            when { branch 'main' }
            steps {
                script {
                    // Login to ECR and push images
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REGISTRY}
                        docker tag ${ECR_REPO}:${IMAGE_TAG} ${ECR_REPO}:latest
                        docker push ${ECR_REPO}:${IMAGE_TAG}
                        docker push ${ECR_REPO}:latest
                    """
                }

                // Deploy to production EC2 using SSH
                script {
                    sh """
                        ssh -i ~/.ssh/anna_key_home.pem -o StrictHostKeyChecking=no ubuntu@${PROD_IP} \\
                        'docker pull ${ECR_REPO}:latest && \\
                         docker rm -f ${IMAGE_NAME} || true && \\
                         docker run -d --name ${IMAGE_NAME} -p 5000:5000 --restart=always ${ECR_REPO}:latest'
                    """
                }
                // Health check
                script {
                    def ok = false
                    for (int i=0; i<6; i++) {
                        sleep 5
                        def rc = sh(script: "curl -fsS http://${PROD_IP}:5000/health >/dev/null 2>&1 || echo FAIL", returnStdout: true).trim()
                        if (rc == '') { ok = true; break }
                    }
                    if (!ok) { error "Health check failed!" }
                }
            }
        }
    }
}





