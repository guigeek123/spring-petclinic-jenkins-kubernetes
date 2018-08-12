#!/bin/bash

printf "\n Setting up port forwarding to sonar ..."

export SONAR_POD_NAME=$(kubectl get pods -l "app=sonarqube,release=vocal-tortoise" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $SONAR_POD_NAME 9000:9000 >> /dev/null &
#printf "Sonar POD NAME : $SONAR_POD_NAME \n" 

printf "\nPort forwarding OK : you can now acces sonar on port 9000\n\n"
