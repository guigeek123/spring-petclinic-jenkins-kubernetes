#!/bin/bash


validate_environment() {
  # Check pre-requisites for required command line tools
 command -v kubectl >/dev/null 2>&1 || { echo >&2 "Kubernetes commands required - doesn't seem to be on your path.  Aborting."; exit 1; }
}


show_passwords() {
  printf "Default login / passwords :\n"
  printf " Jenkins :\n"
  printf "   - Login : admin\n"
  printf "   - Password : "
  printf $(kubectl get secret cd-jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo
  printf "\n"
  printf " DefectDojo :\n"
  printf "   - Login : admin\n"
  printf "   - Password : admin\n"
  printf "\n"
  printf " Nexus :\n"
  printf "   - Login : admin\n"
  printf "   - Password : "
  printf $(kubectl get secret nexus-admin-pass -o jsonpath="{.data.password}" | base64 --decode);echo
  printf "\n"
  printf " Sonar :\n"
  printf "   - Login : admin\n"
  printf "   - Password : admin\n"
  printf "\n"
  printf " Dependency Track :\n"
  printf "   - Login : admin\n"
  printf "   - Password : admin\n\n"
}


validate_environment
show_passwords
