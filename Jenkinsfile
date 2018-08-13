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
                  sh 'mvn -s maven-custom-settings help:effective-settings'      
                  sh 'mvn -s maven-custom-settings clean verify sonar:sonar'}
        }
   
	stage('Build with Maven and artifact push to Nexus') {
		container('maven') {
			sh 'mvn -s maven-custom-settings clean deploy -DskipTests'}
	}


        stage('Download Artifcat from Nexus') {
                container('maven') {
                        sh 'mkdir targetDocker'
			sh 'cd targetDocker && mvn -s ../maven-custom-settings-download org.apache.maven.plugins:maven-dependency-plugin::get -DgroupId=org.springframework.samples -DartifactId=spring-petclinic -Dversion=2.0.0.BUILD-SNAPSHOT -Dpackaging=jar -Ddest=app.jar'}
        }
 
	
	stage('Build and push image with Container Builder') {
		container('gcloud') {
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
