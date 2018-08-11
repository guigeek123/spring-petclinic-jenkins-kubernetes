#!/bin/bash

GCP_PROJECT=${1:-kubepetclinic}
GCP_ZONE=${2:-europe-west1-b}

validate_environment() {
  # Check pre-requisites for required command line tools

 printf "\nChecking pre-requisites for required tooling"

 command -v gcloud >/dev/null 2>&1 || { echo >&2 "Google Cloud SDK required - doesn't seem to be on your path.  Aborting."; exit 1; }

 printf "\nAll pre-requisite software seem to be installed :)"
}

configure_gcp() {
#  gcloud auth application-default login
  gcloud config set project $GCP_PROJECT
  gcloud config set compute/zone $GCP_ZONE

  printf "\nAbout to delete environment (cluster, network, disks, helm config) in the '$GCP_PROJECT' GCP project\n"
  read -rsp $'Press any key to continue...or Ctrl+C to exit\n' -n1 key
}



delete_cluster() {
  #Destroy kubernetes cluster 
  printf "\nAbout to delete Kubernete cluster jenkins-cd\n"
  gcloud container clusters delete jenkins-cd -q
}


delete_disks() {
  #Delete Jenkins Disks
  # This function assumes that only 1 disk is set up within the project. To be updated if not.
  export JENKINS_DISK_NAME=$(gcloud compute disks list --zones=$GCP_ZONE --format="value(name)")
  printf "\nAbout to delete Jenkins Disk with name '$JENKINS_DISK_NAME'\n"
  gcloud compute disks delete $JENKINS_DISK_NAME --zone=$GCP_ZONE -q
}

delete_network() {
  #Destroy networks
  printf "\nAbout to delete jenkins network\n"
  gcloud compute networks delete jenkins -q
}


cleanup_dir() {
  #Cleaning helm dir
  printf "\nCleaning helm home (~/.helm/) dir ...\n"
  rm -r ~/.helm/

  #Cleaning current dir
  printf "\nCleaning helm files within current dir\n"
  rm -f helm
  rm -f helm-v2.9.1-linux-amd64.tar.gz
  rm -rf linux-amd64
}

_main() {

  validate_environment

  configure_gcp

  delete_cluster

  delete_disks

  delete_network

  cleanup_dir
}

_main

