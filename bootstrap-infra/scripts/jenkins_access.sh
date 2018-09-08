#!/bin/bash

printf "Setting up port forwarding for Jenkins ...\n"

export POD_NAME=$(kubectl get pods -l "component=cd-jenkins-master" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $POD_NAME 8080:8080 >> /dev/null &

#printf "\nPort forwarding OK"
