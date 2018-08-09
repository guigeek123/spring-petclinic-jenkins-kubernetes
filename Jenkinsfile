def project = 'kubepetclinic'
def  appName = 'petclinic'
def  feSvcName = "${appName}-frontend"
def  imageTag = "gcr.io/${project}/${appName}:${env.BRANCH_NAME}.${env.BUILD_NUMBER}"

podTemplate(label: 'mypod', containers: [
  containerTemplate(name: 'maven', image: 'maven:alpine', ttyEnabled: true, command: 'cat')
  ], volumes: [
  persistentVolumeClaim(mountPath: '/root/.m2/repository', claimName: 'maven-repo', readOnly: false)
  ]) {

  node('mypod') {
    
	stage('Build with Maven') {
		git 'https://github.com/guigeek123/spring-petclinic-jenkins-kubernetes.git'
		container('maven') {
		  sh 'mvn clean install'
		}
    }
	
  }  
  
}
