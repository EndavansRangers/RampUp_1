#!/bin/bash
set -e

echo "Fixing TeamCity permissions..."
sudo chown -R 1000:1000 /data/teamcity_server
sudo docker restart teamcity-teamcity-1

echo "Waiting for TeamCity to start..."
sleep 10

echo "TeamCity status:"
sudo docker ps | grep teamcity

echo "Done!"
