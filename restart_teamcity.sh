#!/bin/bash
set -e

cd /srv/teamcity

echo "Stopping TeamCity containers..."
sudo docker compose down

echo "Starting TeamCity with updated configuration..."
sudo docker compose up -d

echo "Waiting for containers to start..."
sleep 10

echo "Checking container status..."
sudo docker ps

echo ""
echo "TeamCity agent should now have Docker access!"
echo "Check logs with: sudo docker logs teamcity-agent-1"
