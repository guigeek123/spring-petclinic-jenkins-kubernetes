#!/bin/bash

printf "\n Setting up port forwarding to weave ...\n"

export WEAVE_POD_NAME=$(kubectl get pod -n weave --selector=name=weave-scope-app -o jsonpath={.items..metadata.name})
kubectl port-forward -n weave $WEAVE_POD_NAME 4040:4040 >> /dev/null &


printf "\nPort forwarding OK"
