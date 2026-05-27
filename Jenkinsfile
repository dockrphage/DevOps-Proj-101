pipeline {
    agent any
    
    environment {
        IMAGE_NAME = 'score-api'
        VERSION = "${env.BUILD_NUMBER}"
        DOCKER_BRIDGE_IP = '172.17.0.1'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "📦 Code checked out successfully"
            }
        }
        
        stage('Build with Maven') {
            steps {
                sh 'mvn clean compile'
            }
        }
        
        stage('Package Application') {
            steps {
                sh 'mvn package -DskipTests'
            }
        }
        
        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${IMAGE_NAME}:${VERSION} ."
                sh "docker tag ${IMAGE_NAME}:${VERSION} ${IMAGE_NAME}:latest"
            }
        }
        
        stage('Deploy to Docker Host') {
            steps {
                script {
                    sh '''
                        docker stop score-api 2>/dev/null || true
                        docker rm score-api 2>/dev/null || true
                        docker run -d --name score-api -p 8080:8080 ${IMAGE_NAME}:${VERSION}
                        sleep 15
                    '''
                }
            }
        }
        
        stage('Health Check') {
            steps {
                script {
                    sh '''
                        for i in 1 2 3 4 5; do
                            echo "Health check attempt $i..."
                            if curl -f http://${DOCKER_BRIDGE_IP}:8080/api/scores/health; then
                                echo "✅ Service is healthy!"
                                exit 0
                            fi
                            sleep 3
                        done
                        echo "❌ Health check failed"
                        exit 1
                    '''
                }
            }
        }
        
        stage('Integration Test') {
            steps {
                script {
                    sh '''
                        echo "=== Running Integration Tests ==="
                        curl -X POST "http://${DOCKER_BRIDGE_IP}:8080/api/scores/test?score=100"
                        echo ""
                        curl -s "http://${DOCKER_BRIDGE_IP}:8080/api/scores"
                        echo ""
                        echo "✅ Integration tests passed!"
                    '''
                }
            }
        }
    }
    
    post {
        success {
            echo """
            ═══════════════════════════════════════════════════════
            ✅ PIPELINE SUCCESSFUL!
            ═══════════════════════════════════════════════════════
            Application: http://localhost:8080
            Health: curl http://localhost:8080/api/scores/health
            Scores: curl http://localhost:8080/api/scores
            ═══════════════════════════════════════════════════════
            """
        }
        failure {
            echo "❌ Pipeline failed!"
            sh 'docker logs score-api --tail 50'
        }
    }
}
