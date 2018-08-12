#!/bin/bash

printf "\n Setting up port forwarding to zap ..."

export ZAP_POD_NAME=$(kubectl get pods -l "app=zap" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $ZAP_POD_NAME 8090:8090 >> /dev/null &


printf "\nPort forwarding OK"
