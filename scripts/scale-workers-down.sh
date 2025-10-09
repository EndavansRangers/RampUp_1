#!/bin/bash
# Scale worker nodes DOWN to 0 instances (cost savings)

set -euo pipefail

AWS_REGION="us-east-1"
ASG_NAME="tunefy-dev-wk-asg"

echo "🛑 Scaling DOWN worker nodes to 0 instances (to save costs)..."
echo "ASG: $ASG_NAME"
echo "Region: $AWS_REGION"
echo ""

echo "⚠️  WARNING: This will:"
echo "   - Terminate all worker nodes"
echo "   - Make pods Pending until workers are scaled back up"
echo "   - Save ~\$60/month in compute costs"
echo ""

read -p "Are you sure you want to scale down? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "❌ Aborted. No changes made."
  exit 0
fi

# Set desired capacity to 0
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name "$ASG_NAME" \
  --desired-capacity 0 \
  --region "$AWS_REGION"

echo "✅ ASG desired capacity set to 0"
echo ""
echo "⏳ Waiting for instances to terminate (this may take 1-2 minutes)..."
sleep 60

# Check instance count
INSTANCE_COUNT=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --region "$AWS_REGION" \
  --query 'AutoScalingGroups[0].Instances | length(@)' \
  --output text)

echo "Current instances in ASG: $INSTANCE_COUNT"
echo ""

if [ "$INSTANCE_COUNT" -eq 0 ]; then
  echo "✅ All instances terminated successfully!"
  echo ""
  echo "💰 Cost savings: ~\$2/day (\$60/month) when scaled to 0"
  echo ""
  echo "📝 To scale back up when needed:"
  echo "   ./scripts/scale-workers-up.sh"
else
  echo "⚠️  $INSTANCE_COUNT instance(s) still running. They may still be terminating."
  echo "   Check AWS Console for details."
fi

