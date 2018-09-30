#!/bin/bash
sed -e "s/%ID/$1/g" -e "s/%SECRET/$2/g" scripts/jenkins/cred_SecretText.groovy
