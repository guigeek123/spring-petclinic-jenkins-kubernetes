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
  printf "\nWaiting 20s before checking helm installation\n"
  sleep 20
  ./helm version
}


build_jenkins_server_with_helm() {
  printf "\nInstalling jenkins with Helm ...."
  ./helm install -n cd stable/jenkins -f jenkins/values.yaml --version 0.16.6 --wait
  printf "\nCreating persistent directory for local .m2 ...."
  kubectl apply -f jenkins/k8s/maven-with-cache-pvc.yaml

}  

build_nexus_server_with_helm() {
  printf "\nInstalling nexus with Helm...."
  ./helm install -n nexus stable/sonatype-nexus -f nexus/values.yaml --wait
  #TO BE PATCHED : Creates a service that allows direct access to nexus (no proxy, cause proxy respond "internal error" for now). This service is used in the maven-custom-settings passed to maven during the build.
  kubectl apply -f nexus/k8s/nexus-direct-service.yaml
  #Create a service nodeport to make docker registry available for image deployment in kubernetes (see configuration in deployment yaml)
  kubectl apply -f nexus/k8s/nexus-direct-nodeport.yaml
}

build_sonar_server_with_helm() {
  printf "\nInstalling sonar with Helm ...."
  ./helm install -n sonar stable/sonarqube -f sonar/values.yaml --wait
}


#TO BE DELETED
build_zap_server() {
    printf "\nInstalling ZAP ..."
    kubectl apply -f zap/k8s/deployment-zap.yaml
    kubectl apply -f zap/k8s/service-zap.yaml
}

build_clair_server_with_helm() {
  printf "\nInstalling clair with Helm...."
  #cd boostrap-infra/
  ./helm dependency update clair
  ./helm install -n clair clair -f clair/values.yaml
  #cd $BASE_DIR
}

build_defectdojo_server() {
    printf "\nInstalling DefectDojo ..."
    kubectl apply -f defectdojo/k8s/deployment-defectdojo.yaml
    kubectl apply -f defectdojo/k8s/service-defectdojo.yaml
}

build_ddtrack_server() {
    printf "\nCreating persistent disk for Dependency Track config..."
    kubectl apply -f dependency-track/k8s/ddtrack-cache-pvc.yaml
    printf "\nInstalling Dependency Track ..."
    kubectl apply -f dependency-track/k8s/deployment-ddtrack.yaml
    kubectl apply -f dependency-track/k8s/service-ddtrack.yaml
}

create_namespaces() {
  printf "\nCreate namespaces\n"
  kubectl create ns testing
  kubectl create ns acceptance
  kubectl create ns production

}

configure_nexus() {
  #Create access to nexus POD
  scripts/wait-for-deployment.sh nexus-sonatype-nexus
  scripts/nexus_access.sh
  printf "\nAbout to configure Jenkins ...\n"
  while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' localhost:8081)" != "200" ]]; do sleep 5; done

  # Creating docker repositories
  printf "\nCreating docker repositories ...\n"
  curl -u admin:admin123 -X POST --header 'Content-Type: application/json'  http://localhost:8081/service/rest/v1/script  -d @nexus/configScripts/createDockerRepo.json
  curl -X POST -u admin:admin123 --header "Content-Type: text/plain" 'http://localhost:8081/service/rest/v1/script/docker/run'
  curl -u admin:admin123 -X DELETE http://localhost:8081/service/rest/v1/script/docker

  #Generate random admin password for Nexus and save it into a kubernetes secret
  printf "\nCreating random admin password for Nexus...."
  echo -n 'admin' > ./username
  date +%s | sha256sum | head -c 10 > ./password
  printf "\nSaving password into a Kubernetes secret ...."
  kubectl create secret generic nexus-admin-pass --from-file=./username --from-file=./password

  #Update Nexus admin password
  sed -i.bak "s#PASSWORD#$(kubectl get secret nexus-admin-pass -o jsonpath="{.data.password}" | base64 --decode)#" nexus/configScripts/changeAdminPassword.json
  curl -u admin:admin123 -X POST --header 'Content-Type: application/json'  http://localhost:8081/service/rest/v1/script  -d @nexus/configScripts/changeAdminPassword.json
  curl -X POST -u admin:admin123 --header "Content-Type: text/plain" 'http://localhost:8081/service/rest/v1/script/changepass/run'
  curl -u admin:$(kubectl get secret nexus-admin-pass -o jsonpath="{.data.password}" | base64 --decode) -X DELETE http://localhost:8081/service/rest/v1/script/changepass

  printf "\nCreating a specific secret for kaniko to push Docker image on Nexus...."
  #kubectl create configmap docker-config --from-file=kaniko/config.json
  kubectl create secret docker-registry regcred --docker-server=http://nexus-direct:8083/ --docker-username=admin --docker-password=$(kubectl get secret nexus-admin-pass -o jsonpath="{.data.password}" | base64 --decode) --docker-email=admin@admin.com

  #Cleaning files
  rm username
  rm password
  rm nexus/configScripts/changeAdminPassword.json
  mv nexus/configScripts/changeAdminPassword.json.bak nexus/configScripts/changeAdminPassword.json

}

configure_sonar() {
  scripts/wait-for-deployment.sh -t 300 sonar-sonarqube
  scripts/sonar_access.sh
  printf "\nAbout to configure Sonar ...\n"
  #Activate find sec bugs profile
  while [[ "$(curl -u admin:admin -s -o /dev/null -w ''%{http_code}'' localhost:9000/api/webservices/list)" != "200" ]]; do sleep 5; done
  #Wait a bit (sometimes sonar is not ready)
  sleep 20
  curl -v -u admin:admin -X POST "http://localhost:9000/api/qualityprofiles/set_default?language=java&profileName=FindBugs%20Security%20Audit"
}

build_weave() {
  # Tool to vizualize cluster
  printf "\nInstalling Weave ..."
  kubectl create -f 'https://cloud.weave.works/launch/k8s/weavescope.yaml'
}

configure_defectdojo() {
  # Parameters :
  URL=http://localhost:8000
  USER=admin
  DEFAULT_PASSWORD=admin
  JENKINSURL="http://localhost:8080"

  #Generate random admin password for DefectDojo and save it into a kubernetes secret
  printf "\nCreating random admin password for Nexus...."
  echo -n 'admin' > ./dojo_username
  date +%s | sha256sum | head -c 10 > ./dojo_password
  printf "\nSaving password into a Kubernetes secret ...."
  kubectl create secret generic defectdojo-admin-pass --from-file=./dojo_username --from-file=./dojo_password

  #Wait for DefectDojo to  be deployed and up
  scripts/wait-for-deployment.sh -t 300 defectdojo
  scripts/defectdojo_access.sh
  printf "\nAbout to configure DefectDojo ...\n"
  #Activate find sec bugs profile
  while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' localhost:8000/login)" != "200" ]]; do sleep 5; done

  # Open a session with username and password (retrieve the login form CSRF token and then login)
  CSRFTOKEN=`curl -s -c cookies.txt -b cookies.txt $URL/login | grep csrfmiddlewaretoken | awk '{print $7}' | cut -c8-71`
  curl -s -c cookies.txt -b cookies.txt -X POST -F "username=$USER" -F "password=$DEFAULT_PASSWORD" -F "csrfmiddlewaretoken=$CSRFTOKEN" $URL/login

  # Retreive the API key
  curl -s -c cookies.txt -b cookies.txt $URL/api/key | grep " 'Authorization': 'ApiKey" | awk '{print $3}' | cut -c7-46 > dojo_apikey

  # Set up admin email adress (needed for the API to work correctly, otherwize importscan/ fails with error_message: User has no usercontactinfo.)
  CSRFTOKEN=`curl -s -c cookies.txt -b cookies.txt $URL/profile | grep csrfmiddlewaretoken | awk '{print $6}' | cut -c8-71`
  curl -s -c cookies.txt -b cookies.txt -X POST -F "csrfmiddlewaretoken=$CSRFTOKEN" -F "email=nomail@lab.lab" $URL/profile > /dev/null

  # Setup defectdojo options (enable_deduplication and delete_dupulicates)
  CSRFTOKEN=`curl -s -c cookies.txt -b cookies.txt $URL/system_settings | grep csrfmiddlewaretoken | awk '{print $6}' | cut -c8-71`
  curl -s -c cookies.txt -b cookies.txt -X POST -F "csrfmiddlewaretoken=$CSRFTOKEN" \
  -F "enable_deduplication=true" \
  -F "delete_dupulicates=true" \
  -F "product_grade_a=90" \
  -F "product_grade_b=80" \
  -F "product_grade_c=70" \
  -F "product_grade_d=60" \
  -F "product_grade_f=59" \
  -F "engagement_auto_close_days=3" \
  -F "sla_critical=7" \
  -F "sla_high=30" \
  -F "sla_medium=90" \
  -F "sla_low=110" \
  -F "time_zone=Europe/Paris" \
  -F "max_dupes=" \
  -F "enable_jira=" \
  -F "jira_labels=" \
  -F "jira_minimum_severity=" \
  -F "enable_slack_notifications=" \
  -F "slack_channel=" \
  -F "slack_token=" \
  -F "slack_username=" \
  -F "enable_hipchat_notifications=" \
  -F "hipchat_site=" \
  -F "hipchat_channel=" \
  -F "hipchat_token=" \
  -F "enable_mail_notifications=" \
  -F "mail_notifications_from=" \
  -F "mail_notifications_to=" \
  -F "s_finding_severity_naming=" \
  -F "false_positive_history=" \
  -F "url_prefix=" \
  -F "team_name=" \
  -F "display_endpoint_uri=" \
  -F "enable_product_grade=" \
  -F "enable_benchmark=" \
  -F "enable_template_match=" \
  -F "engagement_auto_close=" \
  -F "enable_finding_sla=" \
  $URL/system_settings > /dev/null

  # Change the admin password (must be the last operation because it logs out the user)
  CSRFTOKEN=`curl -s -c cookies.txt -b cookies.txt $URL/change_password | grep csrfmiddlewaretoken | awk '{print $4}' | cut -c8-71`
  curl -s -c cookies.txt -b cookies.txt -X POST -F "csrfmiddlewaretoken=$CSRFTOKEN" -F "current_password=$DEFAULT_PASSWORD" -F "new_password=$(kubectl get secret defectdojo-admin-pass -o jsonpath="{.data.dojo_password}" | base64 --decode)" $URL/change_password

  # Terminate session (logout)
  curl -s -c cookies.txt -b cookies.txt $URL/logout

  # Cleaning
  rm cookies.txt
  rm dojo_username
  rm dojo_password

}

configure_jenkins() {

  scripts/wait-for-deployment.sh -t 300 cd-jenkins
  scripts/jenkins_access.sh
  sleep 5
  printf "\n\nPlease create an admin token in Jenkins and paste it HERE\n"
  printf "Jenkins admin Password is : $(kubectl get secret cd-jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode)"
  printf "\nBrowser will open in 5s ...\n"
  sleep 1
  printf "."
  sleep 1
  printf "."
  sleep 1
  printf "."
  sleep 1
  printf "."
  sleep 1
  printf ".\n"
  sensible-browser "http://localhost:8080/user/admin/configure"
  printf "Jenkins Token ? "
  read JENKINS_TOKEN

  printf "\nTrying to configure DefectDojo API Key in Jenkins...\n"

  ## Setup Jenkins Secret with admin API key <- need additionnal scripts to do so (cred_SecretText.sh and cred_SecretText.groovy, see below)
  DOJO_APIKEY=$(cat dojo_apikey)
  CRUMB="$(curl -s http://localhost:8080/'crumbIssuer/api/xml?xpath=concat(//crumbRequestField,":",//crumb)' -u admin:$JENKINS_TOKEN)"
  curl -d "script=$(scripts/jenkins/cred_SecretText.sh defectdojo_apikey $DOJO_APIKEY)" -H "$CRUMB" --user admin:$JENKINS_TOKEN http://localhost:8080/scriptText

  # Cleaning
  rm dojo_apikey

  printf "\nSetting up demo jobs...\n"
  ./demo_jobs_setup.sh $JENKINS_TOKEN

}



access_main_apps() {

  # Nexus
  sensible-browser "http://localhost:8081/"

  # Sonar
  sensible-browser "http://localhost:9000/"

  # Jenkins
  scripts/wait-for-deployment.sh -t 300 cd-jenkins
  scripts/jenkins_access.sh
  sensible-browser "http://localhost:8080/"

  # DefectDojo
  #scripts/wait-for-deployment.sh -t 300 defectdojo
  #scripts/defectdojo_access.sh
  sensible-browser "http://localhost:8000/"

  # Dependency Track
  scripts/wait-for-deployment.sh -t 300 ddtrack
  scripts/ddtrack_access.sh
  sensible-browser "http://localhost:8380/"

  # Weave
  scripts/wait-for-deployment.sh -n weave -t 300 weave-scope-app
  scripts/weave_access.sh
  sensible-browser "http://localhost:4040/"

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
  # not used anymore : prefer to use docker image in pipeline to allow parralel pipelines
  #build_zap_server

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

  # Setting findsecbugs profile as default
  configure_sonar

  build_weave

  configure_defectdojo

  configure_jenkins

  printf "Configuration instructions and logins will be diplayed here...\n"
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

  # Launch browser when apps are ready
  access_main_apps

  printf "\nCompleted provisioning development environment!!\n\n"

  sh ./show-passwords.sh

  printf "\n\n WARNING  : PLEASE READ WITH ATTENTION"
  printf "\n\n"
  #printf "DON'T FORGET 1 : Manual configuration for DEFECTDOJO is REQUIRED !!!!\n"
  #printf "1 - Get the API key from http://localhost:8000/api/key, to use it Jenkins credential, with ID name 'defectdojo_apikey' \n"
  #printf "2 - Set a (random) contact name (e.g. github section) in admin user config at http://localhost:8000/profile \n"
  #printf "3 - Go to system settings (http://localhost:8000/system_settings) and activate 'Deduplicate findings' and 'Delete duplicates' options\n"
  #printf "4 - Create a product in DefectDojo (will have by default id 1 which is used in Jenkinsfile (stage 'Upload Reports to DefectDojo) by default) \n"
  #printf "\n\n"
  printf "DON'T FORGET : Manual configuration for DEPENDENCY TRACK IS REQUIRED !!!!\n"
  printf "1 - Get the API key from the 'automation' account to use it Jenkins credential, with ID name 'ddtrack_apikey' \n"
  printf "2 - Give the 'PORTFOLIO_MANAGEMENT' access right to the 'automation' account (ability to create projects)"
  printf "\n\n"
  printf "Please not that reports will not be sent to Defectdojo or Dependency Track if api keys are not configured in jenkins\n"
  printf "ADVICE : wait half-an hour before setting Dependency Track API key (Dependency Track takes a long time to download CVEs, with some crashes during this period....)"
  printf "\n\n\n"

}

_main
