#!/bin/bash

printf "\n Setting up port forwarding for Dependency Track...\n"

export DDT_POD_NAME=$(kubectl get pods -l "app=ddtrack" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $DDT_POD_NAME 8380:8080 >> /dev/null &

#printf "\nPort forwarding OK"
