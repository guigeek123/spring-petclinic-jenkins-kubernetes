#!/bin/bash

# Store base directory for starting point of script executions
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd ../ && pwd )"

GCP_PROJECT=${1:-kubepetclinic}
GCP_ZONE=${2:-europe-west1-b}
GCP_MACHINE_TYPE=${3:-n1-standard-2}
NUM_NODES=${4:-2}
#SERVICE_ACCOUNT_FILE=${5:-./service_account.json}

validate_environment() {
  # Check pre-requisites for required command line tools

 printf "\nChecking pre-requisites for required tooling"

 command -v gcloud >/dev/null 2>&1 || { echo >&2 "Google Cloud SDK required - doesn't seem to be on your path.  Aborting."; exit 1; }
 command -v kubectl >/dev/null 2>&1 || { echo >&2 "Kubernetes commands required - doesn't seem to be on your path.  Aborting."; exit 1; }

 printf "\nAll pre-requisite software seem to be installed :)"
}

configure_gcp() {
  gcloud auth application-default login
  gcloud config set project $GCP_PROJECT
  gcloud config set compute/zone $GCP_ZONE

  printf "\nAbout to create a Container Cluster in the '$GCP_PROJECT' GCP project located in '$GCP_ZONE' with $NUM_NODES x '$GCP_MACHINE_TYPE' node(s)\n"
  read -rsp $'Press any key to continue...or Ctrl+C to exit\n' -n1 key
}

create_network() {
  printf "\nCreating jenkins network..."
  gcloud compute networks create jenkins
}

build_gcp_cluster() {
  gcloud container clusters create "jenkins-cd" \
  --zone "$GCP_ZONE" \
  --machine-type "$GCP_MACHINE_TYPE" \
  --num-nodes "$NUM_NODES" \
  --network "jenkins" \
  --scopes "https://www.googleapis.com/auth/projecthosting,storage-rw,cloud-platform"


  #Add yourself as a cluster administrator in the cluster's RBAC so that you can give Jenkins permissions in the cluster
  kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin \
        --user=$(gcloud config get-value account)
  
  #From initial example : 
  #gcloud container clusters get-credentials jenkins-cd
}


install_helm() {
  #Download and install the Helm binary, Unzip the file to your local system
  wget https://storage.googleapis.com/kubernetes-helm/helm-v2.9.1-linux-amd64.tar.gz
  tar zxfv helm-v2.9.1-linux-amd64.tar.gz
  cp linux-amd64/helm .

  #Grant Tiller, the server side of Helm, the cluster-admin role in your cluster:
  kubectl create serviceaccount tiller --namespace kube-system
  kubectl create clusterrolebinding tiller-admin-binding --clusterrole=cluster-admin \
               --serviceaccount=kube-system:tiller

  #Initialize Helm. This ensures that the Tiller is properly installed in your cluster.
  ./helm init --service-account=tiller
  ./helm update

  #Display helm version 
  printf "\nWaiting 15s before checking helm installation\n"
  sleep 15
  ./helm version
}


build_jenkins_server_with_helm() {
  printf "\nInstalling jenkins with Helm ...."
  ./helm install -n cd stable/jenkins -f jenkins/values.yaml --version 0.16.6 --wait
  printf "\nCreating persistent directory for local .m2 ...."
  kubectl apply -f jenkins/maven-with-cache-pvc.yaml

}  

build_nexus_server_with_helm() {
  printf "\nInstalling nexus with Helm...."
  ./helm install -n nexus stable/sonatype-nexus -f nexus/values.yaml --wait
  #TO BE PATCHED : Creates a service that allows direct access to nexus (no proxy, cause proxy respond "internal error" for now). This service is used in the maven-custom-settings passed to maven during the build.
  #TODO : create a single service with multi port mapping
  kubectl apply -f nexus/nexus-direct-service.yaml
  kubectl apply -f nexus/nexus-direct-docker-private-service.yaml
  kubectl apply -f nexus/nexus-direct-docker-group-service.yaml
  #TODO : Automatize Jenkins config to create docker repos.... and then remove warning at the end of the script !!!
}

build_sonar_server_with_helm() {
  printf "\nInstalling sonar ...."
  ./helm install -n sonar stable/sonarqube -f sonar/values.yaml --wait
}


build_zap_server() {
    printf "\nInstalling ZAP ..."
    kubectl apply -f zap/deployment-zap.yaml
    kubectl apply -f zap/service-zap.yaml
}

build_clair_server_with_helm() {
  #TODO : To be tested (not tested yet)
  printf "\nInstalling clair with Helm...."
  #cd boostrap-infra/
  ./helm dependency update clair
  ./helm install -n clair clair -f clair/values.yaml
  #cd $BASE_DIR
  printf "\nCreating configmap for kaniko to push Docker image on Nexus...."
  printf "\nWARNING SECU : Nexus password encoded in Base64 only..."
  kubectl create configmap docker-config --from-file=kaniko/config.json
}


create_namespaces() {
  printf "\nCreate namespaces\n"
  kubectl create ns testing
  kubectl create ns production

}


_main() {

  validate_environment

  printf "\nProvisioning development environment...."

  # Authorise google cloud SDK
  configure_gcp

  # Create dedicated network within GCP
  create_network

  # Utilise terraform to provision the Google Cluster
  build_gcp_cluster

  # Install and configure Helm
  install_helm

  # Install and configure Jenkins using Helm
  build_jenkins_server_with_helm

  # Setup jenkins using helm
  build_nexus_server_with_helm

  # Setup sonar
  build_sonar_server_with_helm

  # Setup ZAP server
  build_zap_server

  # Set up clair
  build_clair_server_with_helm

  # Creates Namespaces for later usage
  create_namespaces

  printf "\nCompleted provisioning development environment!!\n\n"
  printf "\n\n\n\n\n WARNING : DON'T FORGET TO CREATE NEXUS DOCKER REPOSITORIES !!!!!!!!!!! \n\n\n\n\n"
}

_main
