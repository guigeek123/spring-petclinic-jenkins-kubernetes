def project = 'kubepetclinic'
def  appName = 'petclinic'
def  feSvcName = "${appName}-frontend"
def  imageTag = "gcr.io/${project}/${appName}:${env.BUILD_NUMBER}"

podTemplate(serviceAccount:'cd-jenkins', label: 'mypod', containers: [
  containerTemplate(name: 'maven', image: 'maven:alpine', ttyEnabled: true, command: 'cat'),
  containerTemplate(name: 'gcloud', image: 'gcr.io/cloud-builders/gcloud', ttyEnabled: true, command: 'cat'),
  containerTemplate(name: 'kubectl', image: 'gcr.io/cloud-builders/kubectl', ttyEnabled: true, command: 'cat'),
  containerTemplate(name: 'zapcli', image: 'python', ttyEnabled: true, command: 'cat')
  ], volumes: [
	emptyDirVolume(mountPath: '/root/.m2/repository', memory: false)
  ]) {

  node('mypod') {
	stage('Checkout') {
		checkout scm
	}
	
	stage('Check ZAP results') {
		container('zapcli') {
			sh 'pip install python-owasp-zap-v2.4'
			sh 'pip install behave'
			sh 'cd scripts && behave'
			
		}
	}
	
  }  
  
}
