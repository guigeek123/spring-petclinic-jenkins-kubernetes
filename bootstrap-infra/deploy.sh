#!/bin/bash

# Store base directory for starting point of script executions
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd ../ && pwd )"

GCP_PROJECT=${1:-kubepetclinic}
GCP_ZONE=${2:-europe-west1-b}
GCP_MACHINE_TYPE=${3:-n1-standard-2}
NUM_NODES=${4:-4}
#SERVICE_ACCOUNT_FILE=${5:-./service_account.json}

warning_disclaimer() {
  printf "\nIn case of a FIRST RUN, please quit and configure gcloud client with the following command :\n"
  printf "gcloud auth login\n\n"
}

validate_environment() {
  # Check pre-requisites for required command line tools

 printf "\nChecking pre-requisites for required tooling"

 command -v gcloud >/dev/null 2>&1 || { echo >&2 "Google Cloud SDK required - doesn't seem to be on your path.  Aborting."; exit 1; }
 command -v kubectl >/dev/null 2>&1 || { echo >&2 "Kubernetes commands required - doesn't seem to be on your path.  Aborting."; exit 1; }
 command -v curl >/dev/null 2>&1 || { echo >&2 "Curl commands required - doesn't seem to be on your path.  Aborting."; exit 1; }

 printf "\nAll pre-requisite software seem to be installed :)"
}

configure_gcp() {
#  gcloud auth application-default login
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
  printf "\nCreating persistent directory for NVD database (dependency-check) ...."

}  

build_nexus_server_with_helm() {
  printf "\nInstalling nexus with Helm...."
  ./helm install -n nexus stable/sonatype-nexus -f nexus/values.yaml --wait
  #TO BE PATCHED : Creates a service that allows direct access to nexus (no proxy, cause proxy respond "internal error" for now). This service is used in the maven-custom-settings passed to maven during the build.
  kubectl apply -f nexus/nexus-direct-service.yaml
  #Create a service nodeport to make docker registry available for image deployment in kubernetes (see configuration in deployment yaml)
  kubectl apply -f nexus/nexus-direct-nodeport.yaml
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
  printf "\nInstalling clair with Helm...."
  #cd boostrap-infra/
  ./helm dependency update clair
  ./helm install -n clair clair -f clair/values.yaml
  #cd $BASE_DIR
  printf "\nCreating configmap for kaniko to push Docker image on Nexus...."
  printf "\nWARNING SECU : Nexus password encoded in Base64 only..."
  kubectl create configmap docker-config --from-file=kaniko/config.json
}

build_defectdojo_server() {
    printf "\nInstalling DefectDojo ..."
    kubectl apply -f defectdojo/k8s/deployment-defectdojo.yaml
    kubectl apply -f defectdojo/k8s/service-defectdojo.yaml
}

build_ddtrack_server() {
    printf "\nCreating persistent disk for Dependency Track config..."
    kubectl apply -f dependency-track/ddtrack-cache-pvc.yaml
    printf "\nInstalling Dependency Track ..."
    kubectl apply -f dependency-track/deployment-ddtrack.yaml
    kubectl apply -f dependency-track/service-ddtrack.yaml
}

create_namespaces() {
  printf "\nCreate namespaces\n"
  kubectl create ns testing
  kubectl create ns production

}

configure_nexus() {
  #Create access to nexus POD
  #TODO : it assumes that nexus POD has had the time to start... make a proper script to check it
  access-scripts/access_nexus.sh
  while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' localhost:8081)" != "200" ]]; do sleep 5; done
  #TODO : manage nexus password.. (e.g. : script sh to generate a random password, push to nexus, push it to kubernetes secret for later use, and configure associated parts : maven and kaniko within POD Templates in Jenkinsfile)
  curl -u admin:admin123 -X POST --header 'Content-Type: application/json'  http://localhost:8081/service/rest/v1/script  -d @nexus/configScripts/createDockerRepo.json
  curl -X POST -u admin:admin123 --header "Content-Type: text/plain" 'http://localhost:8081/service/rest/v1/script/docker/run'
  #curl -u admin:admin123 -X DELETE http://localhost:8081/service/rest/v1/script/docker

}

access_main_apps() {

  access-scripts/access_defectdojo.sh
  access-scripts/access_jenkins.sh

  # Jenkins
  sensible-browser "http://localhost:8080/"

  # DefectDojo
  sensible-browser "http://localhost:8000/"
}

_main() {

  warning_disclaimer

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

  # Setup DefectDojo
  build_defectdojo_server

  # Set Up Dependency Track server
  build_ddtrack_server

  # Creates docker repo within Nexus
  configure_nexus

  # Creates Namespaces for later usage
  create_namespaces

  printf "\nCompleted provisioning development environment!!\n\n"

  printf "Default login / passwords :\n"
  printf " Jenkins :\n"
  printf "   - Login : admin\n"
  printf "   - Password : will be displayed in this terminal in 5s\n"
  printf " DefectDojo :\n"
  printf "   - Login : admin\n"
  printf "   - Password : admin\n"
  printf " Nexus :\n"
  printf "   - Login : admin\n"
  printf "   - Password : admin123\n"
  printf " Sonar :\n"
  printf "   - Login : admin\n"
  printf "   - Password : admin\n\n"

  printf "\n\n WARNING  : PLEASE READ WITH ATTENTION"
  printf "\n\n"
  printf "DON'T FORGET 1 : Manual configuration for DEFECTDOJO is REQUIRED !!!!\n"
  printf "1 - Get the API key from http://localhost:8000/api/key, to use it Jenkins credential, with ID name 'defectdojo_apikey' \n"
  printf "2 - Set a (random) contact name (e.g. github section) in admin user config at http://localhost:8000/profile \n"
  printf "3 - Go to system settings (http://localhost:8000/system_settings) and activate 'Deduplicate findings' and 'Delete duplicates' options"
  printf "4 - Create a product in DefectDojo (will have by default id 1 which is used in Jenkinsfile (stage 'Upload Reports to DefectDojo) by default) \n"
  printf "\n\n"
  printf "DON'T FORGET 2 : Manual configuration for DEPENDENCY CHECK IS REQUIRED !!!!\n"
  printf "1 - Get the API key from the 'automation' account to use it Jenkins credential, with ID name 'ddtrack_apikey' \n"
  printf "2 - Give the 'PORTFOLIO_MANAGEMENT' access right to the 'automation' account (ability to create projects)"
  printf "\n\n"
  printf "DON'T FORGET 3 : SONAR Configuration !!!!\n"
  printf "1 - WHEN SONAR IS STABLE (kubectl get pods), run ./configure-sonar.sh script\n"
  printf "\n\n\n"


  printf "Accessing main apps to be configured in 5s "
  sleep 1
  printf "."
  sleep 1
  printf "."
  sleep 1
  printf "."
  sleep 1
  printf "."
  sleep 1
  printf "."

  access_main_apps

}

_main
