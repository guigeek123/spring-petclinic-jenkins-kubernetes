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

app1=( "multiBranch" "KubeMultiBranchPetclinic" "https://github.com/guigeek123/petclinic-devsecops-demo" "" )
app2=( "single" "Kubepetclinic2" "https://github.com/guigeek123/petclinic-devsecops-demo.git" "master" )


if [ "${app1[0]}" = "multiBranch" ] ;
then
  scripts/createMultiBranchJob.sh -k $token -g ${app1[2]} ${app1[1]}
else
  scripts/createJob.sh -k $token -b ${app1[3]} -g ${app1[2]} ${app1[1]}
fi
