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

      stage('Build and push image with Container Builder') {
          container('gcloud') {
              sh "PYTHONUNBUFFERED=1 gcloud container builds submit -t ${imageTag} ."
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

              // Deploy to testing namespace, with the docker image created before
              sh("sed -i.bak 's#gcr.io/kubepetclinic/petclinic:37#${imageTag}#' ./k8s/testing/*.yaml")
              sh("sed -i.bak 's#appName#${appName}#' ./k8s/testing/*.yaml")
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
              sh("sed -i.bak 's#gcr.io/kubepetclinic/petclinic:37#${imageTag}#' ./k8s/production/*.yaml")
              sh("kubectl --namespace=production apply -f k8s/services/")
              sh("kubectl --namespace=production apply -f k8s/production/")
              sh("echo http://`kubectl --namespace=production get service/${feSvcName} -o jsonpath='{.status.loadBalancer.ingress[0].ip}'` > ${feSvcName}")
          }
      }


	
  }  
  
}
