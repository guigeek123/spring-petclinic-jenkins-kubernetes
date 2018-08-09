def project = 'kubepetclinic'
def  appName = 'petclinic'
def  feSvcName = "${appName}-frontend"
def  imageTag = "gcr.io/${project}/${appName}:${env.BRANCH_NAME}.${env.BUILD_NUMBER}"

podTemplate(label: 'mypod', containers: [
  containerTemplate(name: 'maven', image: 'maven:alpine', ttyEnabled: true, command: 'cat')
  ]) {

  node('mypod') {
    
	stage('Build with Maven') {
		container('maven') {
		  sh 'mvn clean install'
		}
    }
	
  }  
  
}
