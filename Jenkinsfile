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
  containerTemplate(name: 'claircli', image: 'python:2.7-alpine', ttyEnabled: true, command: 'cat')
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
              //Moving into subdirectory to avoid maven using the POM.XML of the project (makes it fail...)
              sh 'mkdir targetDocker'
              sh 'cd targetDocker && mvn -s ../maven-custom-settings-download org.apache.maven.plugins:maven-dependency-plugin::get -DgroupId=org.springframework.samples -DartifactId=spring-petclinic -Dversion=2.0.0.BUILD-SNAPSHOT -Dpackaging=jar -Ddest=app.jar'
          }
      }

      stage('Build with Kaniko and push image to Nexus Repo') {

          container('gcloud'){
              //Creates a bucket to give context to kaniko for docker image building
              sh "gsutil mb -c nearline gs://${tempBucket}"
              sh 'tar -C . -zcvf /tmp/context/context.tar.gz .'
              sh "gsutil cp /tmp/context/context.tar.gz gs://${tempBucket}"
          }

          container('kubectl'){
              //Personalize kaniko execution config
              sh("sed -i.bak 's#BUCKETNAME#${tempBucket}/context.tar.gz#' ./k8s/kaniko/kaniko.yaml")
              sh("sed -i.bak 's#APPNAME#${appName}#' ./k8s/kaniko/kaniko.yaml")
              sh("sed -i.bak 's#TAG#${env.BUILD_NUMBER}#' ./k8s/kaniko/kaniko.yaml")
              sh "kubectl apply -f k8s/kaniko/kaniko.yaml"
              //Wait for kaniko image to start before viewing logs
              //Displaying logs also allows to wait for building image task to finish before going to next steps
              sh 'sleep 15'
              sh("kubectl logs -f kaniko-${appName}")
              //Require to delete the pod cause it remains with status completed instead
              sh("kubectl delete pod kaniko-${appName}")
          }

          container('gcloud'){
              //Delete the bucket : not required anymore
              sh "gsutil rm -r gs://${tempBucket}"
          }
      }

      stage('Analyse Docker image with CLAIR') {
          // Execute scan and analyse results
          try {
              container('claircli') {
                  // Prerequisites installation on python image
                  // Could be optimized by providing a custom docker image, built and pushed to github before...
                  sh 'pip install --no-cache-dir -r bootstrap-infra/clair/scripts/requirements.txt'

                  // Executing customized Yair script
                  // --no-namespace cause docker image is not pushed withi a "Library" folder in Nexus
                  sh "cd bootstrap-infra/clair/scripts/ && chmod +x yair-custom.py && ./yair-custom.py ${appName}:${env.BUILD_NUMBER} --no-namespace"

                  // TODO : change yair script to generate an html report
                  // Publish Clair Html Report into Jenkins (jenkins plugin required)
                  // publishHTML([allowMissing: false, alwaysLinkToLastBuild: false, keepAll: false, reportDir: 'bootstrap-infra/zap/scripts/', reportFiles: 'results.html', reportName: 'ZAP full report', reportTitles: ''])

              }
          } catch (all) {
              // TODO : ??????
          }

      }


  }  

}
