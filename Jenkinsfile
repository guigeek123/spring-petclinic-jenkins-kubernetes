def project = 'kubepetclinic'
def  appName = 'petclinic'
def  feSvcName = "${appName}-frontend"
def  imageTag = "gcr.io/${project}/${appName}:${env.BRANCH_NAME}.${env.BUILD_NUMBER}"

pipeline {
  agent {
    kubernetes {
      label 'mypod'
      defaultContainer 'jnlp'
      yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    some-label: ci-for-petclinic
spec:
  # Use service account that can deploy to all namespaces
  serviceAccountName: cd-jenkins
  containers:
  - name: maven
    image: maven:alpine
    command:
    - cat
    tty: true
  - name: gcloud
    image: gcr.io/cloud-builders/gcloud
    command:
  - name: kubectl
    image: gcr.io/cloud-builders/kubectl
    command:
    - cat
    tty: true
"""
    }
  }
  stages {
    
	stage('Build with Maven') {
      steps {
        container('maven') {
          sh 'mvn clean install'
        }
      }
    }
	
	stage('TODO - build docker + push docker image') {
		steps {
			container('gcloud') {
				sh "PYTHONUNBUFFERED=1 gcloud container builds submit -t ${imageTag} ."
			}
      }
		
		
    }
	
  }
}
