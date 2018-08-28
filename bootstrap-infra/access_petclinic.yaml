#!/bin/bash

printf "\n Setting up port forwarding to nexus ..."

export APP_POD_NAME=$(kubectl get pods -l "app=petclinic" -o jsonpath="{.items[0].metadata.name}" --namespace=production)
kubectl port-forward $APP_POD_NAME 8180:8080 --namespace=production>> /dev/null &
  #kubectl port-forward $NEXUS_POD_NAME 8082:8082 >> /dev/null &
  #printf "NEXUS POD NAME is : '$NEXUS_POD_NAME'\n"
printf "\nPort forwarding OK"
