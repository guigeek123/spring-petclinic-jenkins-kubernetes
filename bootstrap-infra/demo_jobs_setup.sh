#!/usr/bin/env bash

display_usage_and_exit() {
  echo "Usage: $(basename "$0") <jenkins token api>" >&2
  echo "Arguments:" >&2
  echo "Jenkins Token API REQUIRED: name of the job to create" >&2
  exit 1
}

shift $((OPTIND-1))
if [ "$#" -ne 1 ] ; then
  display_usage_and_exit
fi
readonly token="$1"

app1=( "Kubepetclinic" "https://github.com/guigeek123/spring-petclinic-jenkins-kubernetes.git" "cleaning" )
app2=( "bla2" "https://github.com/guigeek123/spring-petclinic-jenkins-kubernetes.git" "cleaning" )

scripts/createJob.sh -k $token -b ${app1[2]} -g ${app1[1]} ${app1[0]}
#scripts/createJob.sh -k $token -b ${app2[2]} -g ${app2[1]} ${app2[0]}
