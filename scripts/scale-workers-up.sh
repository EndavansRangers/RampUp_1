#!/bin/bash
# Scale worker nodes UP to 2 instances

set -euo pipefail

AWS_REGION="us-east-1"
ASG_NAME="tunefy-dev-wk-asg"

echo "🚀 Scaling UP worker nodes to 2 instances..."
echo "ASG: $ASG_NAME"
echo "Region: $AWS_REGION"
echo ""

# Set desired capacity to 2
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name "$ASG_NAME" \
  --desired-capacity 2 \
  --region "$AWS_REGION"

echo "✅ ASG desired capacity set to 2"
echo ""
echo "⏳ Waiting for instances to launch (this may take 2-3 minutes)..."
echo "   The instances need to:"
echo "   1. Launch from AMI"
echo "   2. Run user-data script"
echo "   3. Join Kubernetes cluster"
echo "   4. Become Ready"
echo ""

# Wait for 2 minutes
sleep 120

# Check instance count
INSTANCE_COUNT=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --region "$AWS_REGION" \
  --query 'AutoScalingGroups[0].Instances | length(@)' \
  --output text)

echo "Current instances in ASG: $INSTANCE_COUNT"
echo ""

if [ "$INSTANCE_COUNT" -eq 2 ]; then
  echo "✅ Both instances are launched!"
  echo ""
  echo "📝 Next steps:"
  echo "1. SSH to Control Plane: ssh -i ~/.ssh/tunefy-dev-key.pem ubuntu@<CP_IP>"
  echo "2. Check worker status: kubectl get nodes"
  echo "3. If workers are NotReady, wait 1-2 more minutes"
  echo "4. If workers don't join automatically, manually join them:"
  echo "   - SSH to worker: ssh -i ~/.ssh/tunefy-dev-key.pem ubuntu@<WORKER_IP>"
  echo "   - Get join command: aws ssm get-parameter --name /tunefy/dev/k8s-join-command --query 'Parameter.Value' --output text --region us-east-1"
  echo "   - Run: sudo <join-command>"
else
  echo "⚠️  Only $INSTANCE_COUNT instance(s) launched. Check ASG status in AWS Console."
fi





