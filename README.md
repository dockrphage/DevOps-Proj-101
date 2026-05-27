Starting with a cleanup script as I'm starting over; this script can also be used to cleanup at the end.

## Part 1: Complete Cleanup Script

```bash
#!/bin/bash
# cleanup.sh - Remove everything and start fresh

echo "=== Starting Complete Cleanup ==="

# Stop and remove Jenkins container
echo "Removing Jenkins container..."
docker stop jenkins 2>/dev/null || true
docker rm jenkins 2>/dev/null || true

# Remove Jenkins volumes
echo "Removing Jenkins volumes..."
docker volume rm jenkins_home 2>/dev/null || true

# Stop and remove application container
echo "Removing application container..."
docker stop score-api 2>/dev/null || true
docker rm score-api 2>/dev/null || true

# Remove Docker images
echo "Removing Docker images..."
docker rmi score-api:latest 2>/dev/null || true
docker rmi score-api:* 2>/dev/null || true
docker rmi jenkins-custom:latest 2>/dev/null || true

# Clean Maven target directory
echo "Cleaning Maven artifacts..."
cd ~/200Proj/DevO-Pro-01 2>/dev/null && mvn clean 2>/dev/null || true

# Remove old Jenkins jobs
echo "Removing Jenkins jobs..."
docker exec jenkins rm -rf /var/jenkins_home/jobs/score-api-pipeline 2>/dev/null || true

# Optional: Remove entire project directory
read -p "Do you want to remove the project directory? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf ~/200Proj/DevO-Pro-01
    echo "Project directory removed"
fi

echo "=== Cleanup Complete ==="
echo ""
echo "Remaining Docker containers:"
docker ps -a
echo ""
echo "Remaining Docker images:"
docker images
```

## Part 2: Complete Step-by-Step Implementation

### **Step 0: Project Setup**

```bash
# Create project directory
mkdir -p ~/200Proj/DevO-Pro-01
cd ~/200Proj/DevO-Pro-01

# Initialize Git repository
git init

# Create GitHub repository (do this on GitHub website first)
# Repository name: devops-score-api
# No README, no .gitignore, no license
```

### **Step 1: Create Spring Boot Application**

```bash
# Create directory structure
mkdir -p src/main/java/com/devops/demo

# Create main application class
cat > src/main/java/com/devops/demo/DemoApplication.java << 'EOF'
package com.devops.demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class DemoApplication {
    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }
}
EOF

# Create REST controller
cat > src/main/java/com/devops/demo/ScoreController.java << 'EOF'
package com.devops.demo;

import org.springframework.web.bind.annotation.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/scores")
public class ScoreController {
    
    private Map<String, Integer> scores = new ConcurrentHashMap<>();
    
    @GetMapping
    public Map<String, Integer> getAllScores() {
        return scores;
    }
    
    @PostMapping("/{player}")
    public String addScore(@PathVariable String player, @RequestParam int score) {
        scores.put(player, scores.getOrDefault(player, 0) + score);
        return String.format("Score added for %s. Total: %d", player, scores.get(player));
    }
    
    @GetMapping("/health")
    public String health() {
        return "OK";
    }
    
    @GetMapping("/info")
    public Map<String, String> info() {
        return Map.of(
            "version", "1.0.0",
            "environment", System.getProperty("spring.profiles.active", "default"),
            "hostname", System.getenv().getOrDefault("HOSTNAME", "unknown")
        );
    }
}
EOF
```

### **Step 2: Create Maven POM**

```bash
cat > pom.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.1.5</version>
        <relativePath/>
    </parent>
    
    <groupId>com.devops</groupId>
    <artifactId>score-api</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>
    
    <properties>
        <java.version>17</java.version>
    </properties>
    
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>
    </dependencies>
    
    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
        <finalName>app</finalName>
    </build>
</project>
EOF
```

### **Step 3: Create Dockerfile**

```bash
cat > Dockerfile << 'EOF'
FROM eclipse-temurin:17-jdk-alpine AS builder
WORKDIR /app
COPY target/app.jar app.jar

FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=builder /app/app.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
EOF
```

### **Step 4: Create Jenkinsfile**

```bash
cat > Jenkinsfile << 'EOF'
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
EOF
```

### **Step 5: Create .gitignore**

```bash
cat > .gitignore << 'EOF'
# Maven
target/
pom.xml.tag
pom.xml.releaseBackup
pom.xml.versionsBackup

# IDE
.idea/
*.iml
.classpath
.project
.settings/
.vscode/

# Docker
docker-compose.override.yml

# Logs
*.log

# OS
.DS_Store
Thumbs.db
EOF
```

### **Step 6: Push to GitHub**

```bash
# Add all files
git add .
git commit -m "Initial commit: Spring Boot Score API with CI/CD pipeline"

# Add remote (replace with your repo URL)
git remote add origin https://github.com/YOUR_USERNAME/devops-score-api.git
git branch -M main
git push -u origin main
```

### **Step 7: Setup Jenkins Container**

```bash
# Create Docker network
docker network create devops-network 2>/dev/null || true

# Run Jenkins container with proper permissions
docker run -d \
  --name jenkins \
  --restart unless-stopped \
  -p 8081:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(which docker):/usr/bin/docker \
  jenkins/jenkins:lts-jdk17

# Wait for Jenkins to start
sleep 20

# Get initial admin password
echo "Jenkins Admin Password:"
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### **Step 8: Install Maven in Jenkins**

```bash
# Install Maven as root
docker exec -it --user root jenkins bash -c "
  apt-get update && apt-get install -y maven
"

# Verify installation
docker exec jenkins mvn --version
```

### **Step 9: Configure Jenkins Job**

**Via UI (Recommended for clarity):**

1. Open http://localhost:8081
2. Use the admin password from Step 7
3. Install suggested plugins
4. Create admin user (follow prompts)
5. Click "New Item" → "Pipeline" → Name: `score-api-pipeline`
6. Under "Pipeline" section:
   - Definition: "Pipeline script from SCM"
   - SCM: "Git"
   - Repository URL: `https://github.com/YOUR_USERNAME/devops-score-api.git`
   - Branches to build: `*/main`
   - Script Path: `Jenkinsfile`
7. Click "Save"

### **Step 10: Trigger First Build**

```bash
# Trigger build via CLI
JENKINS_PASS=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword)
docker exec jenkins curl -X POST "http://localhost:8081/job/score-api-pipeline/build" \
  --user "admin:${JENKINS_PASS}"

# Or click "Build Now" in Jenkins UI
```

## Part 3: Interview Tips & Talking Points

### **Key Concepts to Emphasize**

1. **Why Jenkins?**
   - "Jenkins is the most mature CI/CD tool with 1800+ plugins"
   - "Pipeline as Code (Jenkinsfile) enables version-controlled build definitions"
   - "Self-hosted gives us full control over build environment"

2. **Why Docker?**
   - "Containerization ensures consistency across environments"
   - "Immutable artifacts - what we test is what we deploy"
   - "Fast rollbacks - just restart previous container version"

3. **Why Spring Boot?**
   - "Embedded Tomcat eliminates server configuration"
   - "Production-ready features (actuator, health checks)"
   - "Quick REST API development"

### **Common Interview Questions**

**Q: How do you handle secrets in Jenkins?**
```groovy
// Use Jenkins Credentials
withCredentials([string(credentialsId: 'api-key', variable: 'API_KEY')]) {
    sh 'deploy.sh $API_KEY'
}
```

**Q: How would you scale this?**
- "Add Jenkins agents for parallel builds"
- "Use Kubernetes for orchestration"
- "Implement artifact repository (Nexus/Artifactory)"
- "Add monitoring with Prometheus/Grafana"

**Q: How do you ensure zero-downtime deployments?**
```groovy
stage('Blue-Green Deployment') {
    steps {
        sh '''
            # Start green version
            docker run -d --name app-green -p 8081:8080 app:latest
            
            # Test green
            curl http://localhost:8081/health || exit 1
            
            # Switch traffic
            docker exec proxy nginx -s reload
            
            # Stop blue
            docker stop app-blue
        '''
    }
}
```

**Q: What would you do differently for production?**
1. Add security scanning (SonarQube, Trivy)
2. Implement automated rollbacks
3. Add performance testing
4. Use Helm charts for K8s
5. Implement GitOps with ArgoCD

### **Troubleshooting Cheat Sheet**

| Problem | Solution |
|---------|----------|
| Docker permission denied | `sudo chmod 666 /var/run/docker.sock` |
| Maven not found | `docker exec -it --user root jenkins apt-get install -y maven` |
| Can't reach localhost from Jenkins | Use `172.17.0.1` instead of `localhost` |
| Container won't start | Check logs: `docker logs score-api` |
| Port already in use | `sudo lsof -i :8080 && sudo kill <PID>` |

### **Quick Validation Script**

After setup, run this to verify everything:

```bash
#!/bin/bash
echo "🔍 DevOps Pipeline Validation"
echo "=============================="

echo -n "1. GitHub: "
curl -s https://api.github.com/repos/YOUR_USERNAME/devops-score-api | grep -q "name" && echo "✅" || echo "❌"

echo -n "2. Jenkins: "
curl -s http://localhost:8081/login | grep -q "jenkins" && echo "✅" || echo "❌"

echo -n "3. Docker: "
docker ps | grep -q jenkins && echo "✅" || echo "❌"

echo -n "4. Maven in Jenkins: "
docker exec jenkins mvn --version 2>/dev/null | grep -q "Apache Maven" && echo "✅" || echo "❌"

echo -n "5. Application: "
curl -s http://localhost:8080/api/scores/health | grep -q "OK" && echo "✅" || echo "❌"

echo -n "6. API Functionality: "
curl -s -X POST "http://localhost:8080/api/scores/test?score=100" | grep -q "added" && echo "✅" || echo "❌"

echo -e "\n📊 Pipeline Status: READY FOR INTERVIEW!"
```

## Part 4: Interview Demo Script

Practice this 5-minute demo:

```
"I'll demonstrate my complete CI/CD pipeline:

1. [Show GitHub] - Here's my source code with Spring Boot REST API

2. [Show Jenkins] - Any code push triggers this pipeline:
   - Maven builds and tests
   - Docker creates container image
   - Deploys to Docker host

3. [Show running app] - Let me test the API:
   curl http://localhost:8080/api/scores/health
   [Shows OK]
   
   curl -X POST "http://localhost:8080/api/scores/demo?score=42"
   [Shows success]
   
   curl http://localhost:8080/api/scores
   [Shows data]

4. [Show rollback] - If deployment fails, I can instantly roll back:
   docker stop score-api && docker run -d --name score-api -p 8080:8080 score-api:previous

This pipeline ensures consistent, repeatable deployments with minimal downtime."
```

Great project for DevOps interview questions about CI/CD pipelines! 🚀