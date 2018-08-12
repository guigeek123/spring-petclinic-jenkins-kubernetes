def project = 'kubepetclinic'
def  appName = 'petclinic'
def  feSvcName = "${appName}-frontend"
def  imageTag = "gcr.io/${project}/${appName}:${env.BUILD_NUMBER}"

podTemplate(serviceAccount:'cd-jenkins', label: 'mypod', containers: [
  containerTemplate(name: 'maven', image: 'maven:alpine', ttyEnabled: true, command: 'cat'),
  containerTemplate(name: 'gcloud', image: 'gcr.io/cloud-builders/gcloud', ttyEnabled: true, command: 'cat'),
  containerTemplate(name: 'kubectl', image: 'gcr.io/cloud-builders/kubectl', ttyEnabled: true, command: 'cat')
  ], volumes: [
	emptyDirVolume(mountPath: '/root/.m2/repository', memory: false)
  ]) {

  node('mypod') {
	stage('Checkout') {
		checkout scm
	}


        stage('Run Sonar analysis') {
                container('maven') {
                  sh 'mvn help:effective-settings'      
                  sh 'mvn -s maven-custom-settings clean verify sonar:sonar'}
        }
   
	stage('Build with Maven') {
		container('maven') {
			sh 'mvn -s maven-custom-settings clean deploy -DskipTests'}
	}
 
	
	stage('Build and push image with Container Builder') {
		container('gcloud') {
			sh 'cp /root/.m2/repository/org/springframework/samples/spring-petclinic/2.0.0.BUILD-SNAPSHOT/spring-petclinic-2.0.0.BUILD-SNAPSHOT.jar .'
          sh "PYTHONUNBUFFERED=1 gcloud container builds submit -t ${imageTag} ."
        }
    }
	
	
	stage('Deploy to Kube') {
		container('kubectl') {
			sh("sed -i.bak 's#gcr.io/kubepetclinic/petclinic:37#${imageTag}#' ./k8s/production/*.yaml")
			sh("kubectl --namespace=production apply -f k8s/services/")
			sh("kubectl --namespace=production apply -f k8s/production/")
			sh("echo http://`kubectl --namespace=production get service/${feSvcName} -o jsonpath='{.status.loadBalancer.ingress[0].ip}'` > ${feSvcName}")
		}
	}
	
  }  
  
}
