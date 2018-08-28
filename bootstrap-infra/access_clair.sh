#!/bin/bash

printf "Your password for clair access is : "
#printf $(kubectl get secret cd-jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo

printf "\n Setting up port forwarding ..."

export POD_NAME=$(kubectl get pods -l "app=clair" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $POD_NAME 6060:6060 >> /dev/null &

printf "\nPort forwarding OK"
