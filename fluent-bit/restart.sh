#!/bin/bash
echo "Deleting DaemonSet and configmap"
kubectl delete -f artifacts/fluent-bit-ds.yaml
kubectl delete -f artifacts/fluent-bit-configmap-nginx.yaml

sleep 3s
echo "Creating configmap.."
kubectl apply -f artifacts/fluent-bit-configmap-nginx.yaml
kubectl apply -f artifacts/fluent-bit-ds.yaml
echo "wait 5 seconds ..."
sleep 5s    
echo "Obtaining the logs .. "


kubectl logs --tail=15 $(kubectl get pods  -l "k8s-app=fluent-bit-kube-system" -o jsonpath="{.items[0].metadata.name}")

echo
echo "Printing configmap's regex"

kubectl describe configmap fluent-bit-config | grep Regex