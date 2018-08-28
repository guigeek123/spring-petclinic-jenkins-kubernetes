def project = 'kubepetclinic'
def  appName = 'petclinic'
def  feSvcName = "${appName}-frontend"
def  imageTag = "${appName}:${env.BUILD_NUMBER}"
def tempBucket = "${project}-${appName}-${env.BUILD_NUMBER}"

podTemplate(serviceAccount:'cd-jenkins', label: 'mypod', containers: [
  containerTemplate(name: 'maven', image: 'maven:alpine', ttyEnabled: true, command: 'cat'),
  containerTemplate(name: 'gcloud', image: 'gcr.io/cloud-builders/gcloud', ttyEnabled: true, command: 'cat'),
  containerTemplate(name: 'kubectl', image: 'gcr.io/cloud-builders/kubectl', ttyEnabled: true, command: 'cat'),
  containerTemplate(name: 'zapcli', image: 'python:3.7-alpine', ttyEnabled: true, command: 'cat'),
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

      stage('Run Sonar analysis') {
          container('maven') {
              sh 'mvn -s maven-custom-settings clean verify sonar:sonar'
          }
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

      stage('DAST with ZAP') {
          /**
           * This step deploys the application into a namespace dedicated to test ("testing")
           * The ZAP is running inside the default namespace, so we deploy also what is called here an "internamespace" service, which make available the target app from the default namespace
           * The ZAP server has been deployed during the "environment deployment"
           * The 'zapcli' container is a python based container which runs scripts to launch DAST from ZAP server, dumps results, push it to Jenkins, and analyses it using Behave and the policy implemented in boostrap-infra/zap/scripts/features/
           * Then the app and internamespace service are destroyed
           * NOTE : this step remains "non blocking" for now (using the try catch below)
           *
           * TODO :
           *   MANDATORY :
           *   - Wait for service & deployment to be upp before starting zap testing
           *
           *   OPTIMIZATION / BACK LOG
           *   - Make this stage not required for all push (e.g. : only for push on a specific branch ...)
           *
           *   - Add a call to "New Session" ZAP function
           *   - Add more policy rules using behave scenario
           *   - Add functions to create / load a zap session (simpler way : create new unique session at each build ; better way : learn to use zap iteratively in the same zap session...)
           *   - Add functions for detailed zap configuration : push and load zap context files...
           *
           *   OR (better !)
           *
           *   - Migrate to BDD Security
           *
           * */

          // For now : using a demo app
          container('kubectl') {
              // Create dedicated deployment yaml for testing in order not to be confused later with deployment in production
              sh 'mkdir ./k8s/testing/'
              sh 'cp ./k8s/production/frontend.yaml k8s/testing/'
              sh 'cp ./k8s/services/frontend.yaml k8s/testing/frontend-service.yaml'

              //Get node internal ip to access nexus docker registry exposed as nodePort (nexus-direct-nodeport.yaml) and replace it yaml file
              sh 'sed -i.bak \"s#NODEIP#$(kubectl get nodes -o jsonpath="{.items[1].status.addresses[?(@.type==\\"InternalIP\\")].address}")#\" ./k8s/testing/frontend.yaml'
              //Write the image to be deployed in the yaml deployment file
              sh("sed -i.bak 's#CONTAINERNAME#${imageTag}#' ./k8s/testing/frontend.yaml")
              //Personalizes the deployment file with application name
              sh("sed -i.bak 's#appName#${appName}#' ./k8s/testing/*.yaml")
              // Deploy to testing namespace, with the docker image created before
              sh 'kubectl apply -f ./k8s/testing/frontend.yaml --namespace=testing'
              sh 'kubectl apply -f ./k8s/testing/frontend-service.yaml --namespace=testing'

              // Deploy an "internamespace service" to make the testing app accessible from the default namespace where zap is running
              sh("sed -i.bak 's#appName#${appName}#' ./k8s/services/internamespace-frontend.yaml")
              sh 'kubectl apply -f ./k8s/services/internamespace-frontend.yaml'
          }


          // Execute scan and analyse results
          try {
              container('zapcli') {
                  // Prerequisites installation on python image
                  //   Could be optimized by providing a custom docker image, built and pushed to github before...
                  sh 'pip install python-owasp-zap-v2.4'
                  sh 'pip install behave'

                  //Give a chance to app to start
                  //TODO : find a good "wait" method
                  sh 'sleep 30'
                  //Check if the app is available (should show some html source code in logs)
                  sh "curl http://${appName}-frontend-defaultns/"

                  // Executing zap client python scripts
                  sh "cd bootstrap-infra/zap/scripts/ && chmod +x pen-test-app.py && ./pen-test-app.py --zap-host zap-proxy-service:8090 --target http://${appName}-frontend-defaultns/"

                  // Publish ZAP Html Report into Jenkins (jenkins plugin required)
                  publishHTML([allowMissing: false, alwaysLinkToLastBuild: false, keepAll: false, reportDir: 'bootstrap-infra/zap/scripts/', reportFiles: 'results.html', reportName: 'ZAP full report', reportTitles: ''])

                  // Analysing results using behave
                  sh 'cd bootstrap-infra/zap/scripts/ && behave'
              }
          } catch (all) {
              // We get in this catch at least if the policy is not respected (behave launches an error)
              // TODO : Decide what to do when policy is not respected. For now, to allow demo, we do not want to break the build
          }

          // Destroy app from testing namespace
          container('kubectl') {
              sh "kubectl delete service ${appName}-frontend-defaultns"
              sh "kubectl delete deployment ${appName}-frontend-deployment --namespace=testing"
              sh "kubectl delete service ${appName}-frontend --namespace=testing"
          }
      }

      stage('Deploy to Kube') {
          container('kubectl') {
              //Get node internal ip to access nexus docker registry exposed as nodePort (nexus-direct-nodeport.yaml) and replace it yaml file
              sh 'sed -i.bak \"s#NODEIP#$(kubectl get nodes -o jsonpath="{.items[1].status.addresses[?(@.type==\\"InternalIP\\")].address}")#\" ./k8s/production/*.yaml'
              //Write the image to be deployed in the yaml deployment file
              sh("sed -i.bak 's#CONTAINERNAME#${imageTag}#' ./k8s/production/*.yaml")
              //Personalizes the deployment file with application name
              sh("sed -i.bak 's#appName#${appName}#' ./k8s/production/*.yaml")
              sh("sed -i.bak 's#appName#${appName}#' ./k8s/services/frontend.yaml")
              //Deploy application
              sh("kubectl --namespace=production apply -f k8s/services/frontend.yaml")
              sh("kubectl --namespace=production apply -f k8s/production/")
              //Display access
              // TODO : put back LoadBalancer deployment, and add a timer to wait for IP attribution
              //sh("echo http://`kubectl --namespace=production get service/${feSvcName} -o jsonpath='{.status.loadBalancer.ingress[0].ip}'` > ${feSvcName}")
          }
      }

  }  

}
