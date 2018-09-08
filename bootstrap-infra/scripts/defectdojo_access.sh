#!/bin/bash

printf "\n Setting up port forwarding to defectdojo ...\n"

export DEFECTDOJO_POD_NAME=$(kubectl get pods -l "app=defectdojo" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $DEFECTDOJO_POD_NAME 8000:8000 >> /dev/null &


#printf "\nPort forwarding OK"
