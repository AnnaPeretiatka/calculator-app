pipeline {
    agent any
	options {
        skipDefaultCheckout(true)
    }
    environment{
        IMAGE_NAME = "annacalc"
        AWS_ACCOUNT_ID = '992382545251'
		AWS_REGION = 'us-east-1'
        REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        ECR_REPO = "${REGISTRY}/${IMAGE_NAME}"
        IMAGE_TAG = 'latest' // default fallback, it PR and main staged overwrite it
		PROD_IP = '54.160.224.36' //EC2 of the app

    }
    stages{
        stage('Checkout'){
			steps {
                checkout([$class: 'GitSCM',
                          branches: [[name: 'main']],
                          userRemoteConfigs: [[
                              url: 'https://github.com/AnnaPeretiatka/calculator-app.git',
                              credentialsId: 'github-pat'
                          ]]])
            }
        }

        stage('CI: build | test (PR) | push to ecr'){
            when {changeRequest()} // only for PR builds
			// docker in docker image + mounts host Docker socket so container for jenkins
			agent {
		        docker {
		            image 'docker:24-dind'
		            args '-v /var/run/docker.sock:/var/run/docker.sock'
					reuseNode true
		        }
		    }
            steps {
				script { env.IMAGE_TAG = "pr-${env.CHANGE_ID}-${env.BUILD_NUMBER}" } // PR-specific tag
				// build and run test stage
		        sh 'docker build --target test -t ${IMAGE_NAME}:${IMAGE_TAG}-test .'
		        sh 'docker run --rm -e PYTHONPATH=/app ${IMAGE_NAME}:${IMAGE_TAG}-test'
				// build production image
				sh 'docker build --target prod -t ${ECR_REPO}:${IMAGE_TAG} .'
				sh 'aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REGISTRY}'
		        sh 'docker push ${ECR_REPO}:${IMAGE_TAG}'
		      }
        }

        stage('CD: Build, Test, Push, Deploy (main)') {
            when {branch 'main'}
			agent {
		        docker {
		            image 'docker:24-dind'
		            args '-v /var/run/docker.sock:/var/run/docker.sock'
					reuseNode true
		        }
		    }
            steps {
				script { env.IMAGE_TAG = "candidate-${env.SHORT_COMMIT ?: env.BUILD_NUMBER}" } // candidate tag
				// build & run test
                sh 'docker build --target test -t ${IMAGE_NAME}:${IMAGE_TAG}-test .'
		        sh 'docker run --rm -e PYTHONPATH=/app ${IMAGE_NAME}:${IMAGE_TAG}-test'
				
				// build prod image inside DinD
				sh 'docker build --target prod -t ${ECR_REPO}:${IMAGE_TAG} .'
				
				// execute login and push outside DinD container
		        script {
		            sh """
		                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REGISTRY}
		                docker tag ${ECR_REPO}:${IMAGE_TAG} ${ECR_REPO}:latest
		                docker push ${ECR_REPO}:${IMAGE_TAG}
		                docker push ${ECR_REPO}:latest
		            """
		        }
				
				// deploy to production EC2 using SSH credential
        		withCredentials([sshUserPrivateKey(credentialsId: 'prod-ssh-key', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
          			sh """
			 		ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no ${SSH_USER}@${PROD_IP} \
                        'docker pull ${ECR_REPO}:latest && \
                         docker rm -f ${IMAGE_NAME} || true && \
                         docker run -d --name ${IMAGE_NAME} -p 5000:5000 --restart=always ${ECR_REPO}:latest'
			 		"""
				}

				//health check with retry loop
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

        

















