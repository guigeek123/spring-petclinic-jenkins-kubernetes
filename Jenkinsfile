def project = 'kubepetclinic'
def  appName = 'petclinic'
def  feSvcName = "${appName}-frontend"
def  imageTag = "gcr.io/${project}/${appName}:${env.BUILD_NUMBER}"
def  imageTagLocal = "nexus-direct:8083/${project}/${appName}:${env.BUILD_NUMBER}"
def tempBucket = "${project}-${appName}-${env.BUILD_NUMBER}"

podTemplate(serviceAccount:'cd-jenkins', label: 'mypod', containers: [
  containerTemplate(name: 'maven', image: 'maven:alpine', ttyEnabled: true, command: 'cat'),
  containerTemplate(name: 'gcloud', image: 'gcr.io/cloud-builders/gcloud', ttyEnabled: true, command: 'cat'),
  containerTemplate(name: 'kubectl', image: 'gcr.io/cloud-builders/kubectl', ttyEnabled: true, command: 'cat'),
  //containerTemplate(name: 'zapcli', image: 'python', ttyEnabled: true, command: 'cat'),
  //containerTemplate(name: 'claircli', image: 'yfoelling/yair', ttyEnabled: true, command: 'cat'),
  //containerTemplate(name: 'kaniko', image: 'gcr.io/kaniko-project/executor:latest', ttyEnabled: true, command: 'cat')
  ], volumes: [
        persistentVolumeClaim(mountPath: '/root/.m2/repository', claimName: 'maven-repo', readOnly: false),
        emptyDirVolume(mountPath: '/tmp/context/', memory: false)
        //emptyDirVolume(mountPath: '/root/.m2/repository', memory: false)
  ]) {

  node('mypod') {
      stage('Checkout') {
          checkout scm
      }

      stage('Build with Maven and push artifact to Nexus') {
          container('maven') {
              sh 'mvn -s maven-custom-settings clean deploy -DskipTests'
          }
      }

      stage('Download Artifact from Nexus') {
          container('maven') {
              sh 'mkdir targetDocker'
              sh 'cd targetDocker && mvn -s ../maven-custom-settings-download org.apache.maven.plugins:maven-dependency-plugin::get -DgroupId=org.springframework.samples -DartifactId=spring-petclinic -Dversion=2.0.0.BUILD-SNAPSHOT -Dpackaging=jar -Ddest=app.jar'
          }
      }

      /**stage('Create temp bucket'){
      *    container('gcloud'){
      *        sh "gsutil mb -c nearline gs://${tempBucket}"
      *        //TODO : how to current directory without changing it ?
      *        sh 'tar -C . -zcvf context.tar.gz .'
      *        sh "gsutil cp context.tar.gz gs://${tempBucket}"
      *    }
      } */

      stage('Build with Kaniko and push image to Nexus Repo') {
          container('kubectl'){
              sh 'tar -C . -zcvf context.tar.gz /tmp/context/'
              //sh("sed -i.bak 's#BUCKETNAME#gs://${tempBucket}#' ./k8s/kaniko/kaniko.yaml")
              sh "kubectl apply -f k8s/kaniko/kaniko.yaml"
          }
      }

      stage('Delete bucket'){
          container('gcloud'){
              sh "gsutil rm -r gs://${tempBucket}"
          }
      }

      /** stage('Build and push image with Container Builder') {
      *    container('gcloud') {
      *        sh "PYTHONUNBUFFERED=1 gcloud container builds submit -t ${imageTag} ."
      *    }
      *}
       */


  }  

}
