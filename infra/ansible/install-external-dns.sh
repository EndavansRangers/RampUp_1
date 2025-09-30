#!/bin/bash
helm upgrade --install external-dns bitnami/external-dns \
  -n kube-system \
  --set provider=aws \
  --set policy=sync \
  --set registry=txt \
  --set txtOwnerId=tunefy-dev \
  --set domainFilters={endavarangers.com}