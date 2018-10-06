#!/usr/bin/env bash

pkill kubectl

# Nexus
./nexus_access.sh
sensible-browser "http://localhost:8081/"

# Sonar
./sonar_access.sh
sensible-browser "http://localhost:9000/"

# Jenkins
./jenkins_access.sh
sensible-browser "http://localhost:8080/"

# DefectDojo
./defectdojo_access.sh
sensible-browser "http://localhost:8000/"

# Dependency Track
./ddtrack_access.sh
sensible-browser "http://localhost:8380/"

# Weave
./weave_access.sh
sensible-browser "http://localhost:4040/"
