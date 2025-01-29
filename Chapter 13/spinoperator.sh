#!/bin/bash

# from https://github.com/spinkube/documentation/blob/main/content/en/docs/spin-operator/quickstart/_index.md

k3d cluster create wasm-cluster \
  --image ghcr.io/spinkube/containerd-shim-spin/k3d:v0.13.1 \
  -p "8081:80@loadbalancer" \
  --agents 2

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.3/cert-manager.yaml
kubectl apply -f https://github.com/spinkube/spin-operator/releases/download/v0.1.0/spin-operator.runtime-class.yaml
kubectl apply -f https://github.com/spinkube/spin-operator/releases/download/v0.1.0/spin-operator.crds.yaml

# wait for all of these to complete
sleep 30

# Install Spin Operator with Helm
helm install spin-operator \
  --namespace spin-operator \
  --create-namespace \
  --version 0.1.0 \
  --wait \
  oci://ghcr.io/spinkube/charts/spin-operator

kubectl apply -f https://github.com/spinkube/spin-operator/releases/download/v0.1.0/spin-operator.shim-executor.yaml


spin kube scaffold -f ghcr.io/petersalomonsen/imageclassify -o spinapp.yaml --autoscaler keda --cpu-limit 100m --memory-limit 128Mi --replicas 0 --max-replicas 1