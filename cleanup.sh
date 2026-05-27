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
