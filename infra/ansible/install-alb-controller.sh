#!/bin/bash
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system --create-namespace \
  --set clusterName=tunefy-dev \
  --set region=us-east-1 \
  --set vpcId=vpc-020517f941f39faeb \
  --set serviceAccount.create=true \
  --set image.repository=amazon/aws-load-balancer-controller