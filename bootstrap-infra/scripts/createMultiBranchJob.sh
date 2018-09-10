#!/usr/bin/env bash

DEFAULT_JENKINS_URL=http://localhost:8080/
DEFAULT_JENKINS_USER=admin
DEFAULT_BRANCH=master
TEMPLATE_PATH=seedjobs/multiBranchJobConfig.xml

display_usage_and_exit() {
  echo "Usage: $(basename "$0") [-k <jenkins token>] [-f <XML job description relative file path>] <jobName>" >&2
  echo "Arguments:" >&2
  echo "jobName REQUIRED: name of the job to create" >&2
  echo "-k REQUIRED: Jenkins token api for admin user (default) or user specified with '-u' option" >&2
  echo "-b REQUIRED: Github URL of project" >&2
  echo "-u OPTIONAL: Jenkins user, default is 'admin" >&2
  echo "-n OPTIONAL: Jenkins URL with port, default is 'http://localhost:8080/" >&2
  exit 1
}

configure_template() {
  cp ${path} ${path}.bak
  sed -i "s#GITHUBURL#${githubprojecturl}#" ${path}
}


create_job() {
  CRUMB=$(curl -s ${url}'crumbIssuer/api/xml?xpath=concat(//crumbRequestField,":",//crumb)' -u $user:$token)
  curl -s -XPOST "${url}createItem?name=${jobname}" -u ${user}:${token} --data-binary @${path} -H "$CRUMB" -H "Content-Type:text/xml"
}

clean() {
  rm ${path}
  mv ${path}.bak ${path}
}

start_job() {
  CRUMB=$(curl -s ${url}'crumbIssuer/api/xml?xpath=concat(//crumbRequestField,":",//crumb)' -u $user:$token)
  curl -X POST "${url}job/${jobname}/build" -H "$CRUMB" -u ${user}:${token}
}


url=${DEFAULT_JENKINS_URL}
user=${DEFAULT_JENKINS_USER}
branch=${DEFAULT_BRANCH}
path=${TEMPLATE_PATH}

while getopts ':k:u:n:b:g:' arg
do
    case ${arg} in
        n) url=${OPTARG};;
        t) user=${OPTARG};;
        k) token=${OPTARG};;
        g) githubprojecturl=${OPTARG};;
        *) display_usage_and_exit
    esac
done


shift $((OPTIND-1))
if [ "$#" -ne 1 ] ; then
  display_usage_and_exit
fi
readonly jobname="$1"

if [ -z "$token" ] ; then
  display_usage_and_exit
fi

if [ -z "$githubprojecturl" ] ; then
  display_usage_and_exit
fi

configure_template
create_job
clean
#start_job
