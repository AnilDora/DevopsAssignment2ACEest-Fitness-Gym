pipeline {
    agent any
    
    environment {
        // Application Configuration
        APP_NAME = 'aceest-fitness'
        DOCKER_IMAGE = 'yourdockerhub/aceest-fitness'
        DOCKER_REGISTRY = 'https://registry.hub.docker.com'
        DOCKER_CREDENTIALS_ID = 'dockerhub-credentials'
        
        // Git Configuration
        GIT_CREDENTIALS_ID = 'github-credentials'
        
        // Kubernetes Configuration
        KUBECONFIG_CREDENTIALS_ID = 'kubeconfig'
        K8S_NAMESPACE = 'aceest-fitness'
        
        // SonarQube Configuration
        SONAR_HOST_URL = 'http://sonarqube:9000'
        SONAR_PROJECT_KEY = 'aceest-fitness'
        
        // Version Configuration
        VERSION = "${env.BUILD_NUMBER}"
        IMAGE_TAG = "v${VERSION}"
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 1, unit: 'HOURS')
    }
    
    stages {
        stage('Checkout') {
            steps {
                script {
                    echo '📥 Checking out source code...'
                    checkout scm
                    
                    // Get commit information
                    env.GIT_COMMIT_SHORT = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()
                    env.GIT_COMMIT_MSG = sh(
                        script: "git log -1 --pretty=%B",
                        returnStdout: true
                    ).trim()
                    
                    echo "Git Commit: ${env.GIT_COMMIT_SHORT}"
                    echo "Commit Message: ${env.GIT_COMMIT_MSG}"
                }
            }
        }
        
        stage('Install Dependencies') {
            steps {
                script {
                    echo '📦 Installing Python dependencies...'
                    sh '''
                        python -m venv venv
                        . venv/bin/activate
                        pip install --upgrade pip
                        pip install -r requirements.txt
                    '''
                }
            }
        }
        
        stage('Lint & Code Quality') {
            steps {
                script {
                    echo '🔍 Running code quality checks...'
                    sh '''
                        . venv/bin/activate
                        pip install flake8 pylint
                        flake8 app.py --max-line-length=120 --exclude=venv || true
                        pylint app.py --disable=C0111,C0103 || true
                    '''
                }
            }
        }
        
        stage('Unit Tests') {
            steps {
                script {
                    echo '🧪 Running unit tests...'
                    sh '''
                        . venv/bin/activate
                        pytest test_app.py -v --junitxml=test-results.xml --cov=app --cov-report=xml --cov-report=html
                    '''
                }
            }
            post {
                always {
                    junit 'test-results.xml'
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'htmlcov',
                        reportFiles: 'index.html',
                        reportName: 'Coverage Report'
                    ])
                }
            }
        }
        
        stage('SonarQube Analysis') {
            steps {
                script {
                    echo '📊 Running SonarQube analysis...'
                    withSonarQubeEnv('SonarQube') {
                        sh '''
                            sonar-scanner \
                                -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                                -Dsonar.sources=. \
                                -Dsonar.host.url=${SONAR_HOST_URL} \
                                -Dsonar.python.coverage.reportPaths=coverage.xml \
                                -Dsonar.exclusions=venv/**,test_*.py
                        '''
                    }
                }
            }
        }
        
        stage('Quality Gate') {
            steps {
                script {
                    echo '🚦 Checking SonarQube quality gate...'
                    timeout(time: 5, unit: 'MINUTES') {
                        waitForQualityGate abortPipeline: true
                    }
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    echo '🐳 Building Docker image...'
                    docker.build("${DOCKER_IMAGE}:${IMAGE_TAG}")
                    docker.build("${DOCKER_IMAGE}:latest")
                }
            }
        }
        
        stage('Security Scan') {
            steps {
                script {
                    echo '🔒 Scanning Docker image for vulnerabilities...'
                    sh """
                        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                            aquasec/trivy image --severity HIGH,CRITICAL \
                            ${DOCKER_IMAGE}:${IMAGE_TAG} || true
                    """
                }
            }
        }
        
        stage('Push Docker Image') {
            steps {
                script {
                    echo '📤 Pushing Docker image to registry...'
                    docker.withRegistry(DOCKER_REGISTRY, DOCKER_CREDENTIALS_ID) {
                        docker.image("${DOCKER_IMAGE}:${IMAGE_TAG}").push()
                        docker.image("${DOCKER_IMAGE}:latest").push()
                    }
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                script {
                    echo '☸️ Deploying to Kubernetes...'
                    
                    // Choose deployment strategy
                    def deploymentStrategy = env.DEPLOYMENT_STRATEGY ?: 'rolling'
                    
                    withKubeConfig([credentialsId: KUBECONFIG_CREDENTIALS_ID]) {
                        sh """
                            # Create namespace if not exists
                            kubectl create namespace ${K8S_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                            
                            # Update image in deployment
                            kubectl set image deployment/${APP_NAME}-deployment \
                                ${APP_NAME}=${DOCKER_IMAGE}:${IMAGE_TAG} \
                                -n ${K8S_NAMESPACE} || \
                            kubectl apply -f k8s/deployment.yaml
                            
                            # Wait for rollout
                            kubectl rollout status deployment/${APP_NAME}-deployment -n ${K8S_NAMESPACE} --timeout=5m
                        """
                    }
                }
            }
        }
        
        stage('Smoke Tests') {
            steps {
                script {
                    echo '💨 Running smoke tests...'
                    
                    withKubeConfig([credentialsId: KUBECONFIG_CREDENTIALS_ID]) {
                        sh """
                            # Get service URL
                            SERVICE_URL=\$(kubectl get svc ${APP_NAME}-service -n ${K8S_NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
                            
                            # Wait for service to be available
                            for i in {1..30}; do
                                if curl -f http://\${SERVICE_URL}/health; then
                                    echo "✅ Health check passed"
                                    exit 0
                                fi
                                echo "Waiting for service... (\$i/30)"
                                sleep 10
                            done
                            
                            echo "❌ Health check failed"
                            exit 1
                        """
                    }
                }
            }
        }
        
        stage('Tag Release') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo '🏷️ Tagging release...'
                    withCredentials([usernamePassword(
                        credentialsId: GIT_CREDENTIALS_ID,
                        usernameVariable: 'GIT_USERNAME',
                        passwordVariable: 'GIT_PASSWORD'
                    )]) {
                        sh """
                            git config user.name "Jenkins"
                            git config user.email "jenkins@aceest-fitness.com"
                            git tag -a ${IMAGE_TAG} -m "Release ${IMAGE_TAG}"
                            git push https://\${GIT_USERNAME}:\${GIT_PASSWORD}@github.com/yourorg/aceest-fitness.git ${IMAGE_TAG}
                        """
                    }
                }
            }
        }
    }
    
    post {
        success {
            echo '✅ Pipeline completed successfully!'
            
            // Send notification
            emailext(
                subject: "✅ Build Success: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                body: """
                    <h2>Build Successful!</h2>
                    <p><strong>Job:</strong> ${env.JOB_NAME}</p>
                    <p><strong>Build Number:</strong> ${env.BUILD_NUMBER}</p>
                    <p><strong>Version:</strong> ${IMAGE_TAG}</p>
                    <p><strong>Commit:</strong> ${env.GIT_COMMIT_SHORT}</p>
                    <p><strong>Message:</strong> ${env.GIT_COMMIT_MSG}</p>
                    <p><a href="${env.BUILD_URL}">View Build</a></p>
                """,
                to: 'devops@aceest-fitness.com',
                mimeType: 'text/html'
            )
        }
        
        failure {
            echo '❌ Pipeline failed!'
            
            emailext(
                subject: "❌ Build Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                body: """
                    <h2>Build Failed!</h2>
                    <p><strong>Job:</strong> ${env.JOB_NAME}</p>
                    <p><strong>Build Number:</strong> ${env.BUILD_NUMBER}</p>
                    <p><strong>Commit:</strong> ${env.GIT_COMMIT_SHORT}</p>
                    <p><a href="${env.BUILD_URL}">View Build</a></p>
                    <p><a href="${env.BUILD_URL}console">View Console Output</a></p>
                """,
                to: 'devops@aceest-fitness.com',
                mimeType: 'text/html'
            )
        }
        
        always {
            // Cleanup
            cleanWs()
        }
    }
}
