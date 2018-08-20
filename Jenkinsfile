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

      stage('Create temp bucket'){
          container('gcloud'){
              //Creates a bucket to give context to kaniko for docker image building
              sh "gsutil mb -c nearline gs://${tempBucket}"
              sh 'tar -C . -zcvf /tmp/context/context.tar.gz .'
              sh "gsutil cp /tmp/context/context.tar.gz gs://${tempBucket}"
          }
      }

      stage('Build with Kaniko and push image to Nexus Repo') {
          container('kubectl'){
              //Personalize kaniko execution config
              sh("sed -i.bak 's#BUCKETNAME#${tempBucket}/context.tar.gz#' ./k8s/kaniko/kaniko.yaml")
              sh("sed -i.bak 's#APPNAME#${appName}#' ./k8s/kaniko/kaniko.yaml")
              sh("sed -i.bak 's#TAG#${env.BUILD_NUMBER}#' ./k8s/kaniko/kaniko.yaml")
              sh "kubectl apply -f k8s/kaniko/kaniko.yaml"
              //Wait for image to start before view logs
              sh 'sleep 15'
              sh("kubectl logs -f kaniko-${appName}")
              //To verify : is it required to delete pod ?
              //sh("kubectl delete pod kaniko-${appName}")
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
