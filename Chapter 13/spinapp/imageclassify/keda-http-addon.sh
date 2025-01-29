#!/bin/bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda -n keda --create-namespace
helm install http-add-on kedacore/keda-add-ons-http --set interceptor.responseHeaderTimeout=2000ms --namespace keda
kubectl port-forward -n keda svc/keda-add-ons-http-interceptor-proxy 8080:8080