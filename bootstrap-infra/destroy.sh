#!/bin/bash

GCP_PROJECT=${1:-kubepetclinic}
GCP_ZONE=${2:-europe-west1-b}

#Configure env
gcloud config set project $GCP_PROJECT
gcloud config set compute/zone $GCP_ZONE

#Destroy kubernetes cluster 
gcloud container clusters delete jenkins-cd

#Destroy networks
gcloud compute networks delete jenkins

#Cleaning helm dir
printf "Cleaning helm dir ..."
rm -r ~/.helm/

#Cleaning current dir
printf "Cleaning current dir"
rm -f helm
rm -f helm-v2.9.1-linux-amd64.tar.gz
rm -rf linux-amd64
