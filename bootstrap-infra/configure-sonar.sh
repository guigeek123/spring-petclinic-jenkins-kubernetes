#!/bin/bash

warning_disclaimer() {
  printf "\n\nWARNING !!! Check that SONAR is stable (kubectl get pods) before launching this command\n\n"
  read -rsp $'Press any key to continue...or Ctrl+C to exit and check for Sonar status\n' -n1 key

}
validate_environment() {
  # Check pre-requisites for required command line tools

 printf "\nChecking pre-requisites for required tooling"
 command -v curl >/dev/null 2>&1 || { echo >&2 "Curl commands required - doesn't seem to be on your path.  Aborting."; exit 1; }

 printf "\nAll pre-requisite software seem to be installed :)"
}

configure_sonar() {
  access-scripts/access_sonar.sh
  #Activate find sec bugs profile
  while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' localhost:9000)" != "200" ]]; do sleep 5; done
  curl -v -u admin:admin -X POST "http://localhost:9000/api/qualityprofiles/set_default?language=java&profileName=FindBugs%20Security%20Audit"
}

access_sonar() {
  sensible-browser "http://localhost:9000/profiles"
}

_main() {

  warning_disclaimer
  validate_environment
  configure_sonar

  printf "\nCheck that Find Security Bug profile is set as Default for Java on : http://localhost:9000/profiles\n\n"
  printf "Opening default browser in 5s "
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

  access_sonar

}

_main
