#!/bin/bash

printf "\n Setting up port forwarding to nexus ..."

export NEXUS_POD_NAME=$(kubectl get pods -l "app=sonatype-nexus" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $NEXUS_POD_NAME 8081:8081 >> /dev/null &

#printf "NEXUS POD NAME is : '$NEXUS_POD_NAME'\n"
printf "\nPort forwarding OK"
