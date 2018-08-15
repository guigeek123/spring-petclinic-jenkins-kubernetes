#!/usr/bin/env bash

gcloud auth application-default login
gcloud container clusters get-credentials jenkins-cd
