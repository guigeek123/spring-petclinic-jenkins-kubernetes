def project = 'kubepetclinic'
def  appName = 'petclinic'
def  feSvcName = "${appName}-frontend"
def  imageTag = "gcr.io/${project}/${appName}:${env.BRANCH_NAME}.${env.BUILD_NUMBER}"

podTemplate(label: 'mypod', containers: [
  containerTemplate(name: 'maven', image: 'maven:alpine', ttyEnabled: true, command: 'cat'),
  containerTemplate(name: 'gcloud', image: 'gcr.io/cloud-builders/gcloud', ttyEnabled: true, command: 'cat')
  ], volumes: [
	/** emptyDirVolume(mountPath: '/root/.m2/repository', memory: false),*/
	persistentVolumeClaim(mountPath: '/root/.m2/repository', claimName: 'maven-repo', readOnly: false)
  ]) {

  node('mypod') {
	stage('Checkout') {
		checkout scm
	}

/**   
*	stage('Build with Maven') {
*		try {
*			container('maven') {
*				sh 'mvn clean install -DskipTests'
*			}
*		} finally {
*			archiveArtifacts allowEmptyArchive: true, artifacts: '**/target/*.jar'
*        }
*	}
*/ 
	
	stage('Build and push image with Container Builder') {
        git 'https://github.com/guigeek123/spring-petclinic-jenkins-kubernetes.git'
		container('gcloud') {
          sh "PYTHONUNBUFFERED=1 gcloud container builds submit -t ${imageTag} ."
        }
    }
	
  }  
  
}
