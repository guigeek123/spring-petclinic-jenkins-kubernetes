#!/bin/bash

printf "\n Setting up port forwarding for Clair..."

export POD_NAME=$(kubectl get pods -l "app=clair" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $POD_NAME 6060:6060 >> /dev/null &

#printf "\nPort forwarding OK"
