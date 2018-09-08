def project = 'kubepetclinic'
def  appName = 'petclinic'
def  feSvcName = "${appName}-frontend"
def  imageTag = "${appName}:${env.BUILD_NUMBER}"
def tempBucket = "${project}-${appName}-${env.BUILD_NUMBER}"

podTemplate(serviceAccount:'cd-jenkins', label: 'mypod', yaml: """
kind: Pod
metadata:
  name: slave
spec:
  containers:
  - name: maven
    image: maven:alpine
    imagePullPolicy: IfNotPresent
    command:
    - cat
    tty: true
    volumeMounts:
      - name: maven-repo
        mountPath: /root/.m2/repository
        
  - name: kubectl
    image: gcr.io/cloud-builders/kubectl
    imagePullPolicy: IfNotPresent
    command:  
    - cat
    tty: true
    
  - name: zapcli
    image: python:3.7-stretch
    imagePullPolicy: IfNotPresent
    command:  
    - cat
    tty: true

  - name: claircli
    image: python:2.7-alpine
    imagePullPolicy: IfNotPresent
    command:  
    - cat
    tty: true
    
  - name: defectdojocli
    image: python:2.7
    imagePullPolicy: IfNotPresent
    command:  
    - cat
    tty: true
    
  - name: ddtrackcli
    image: python:2.7
    imagePullPolicy: IfNotPresent
    command:  
    - cat
    tty: true    
    
  - name: kaniko
    image: gcr.io/kaniko-project/executor:debug-7a7d5449168da6fb0e45a8cfc625ed7a7e7bd9f3
    imagePullPolicy: IfNotPresent
    command:
    - /busybox/cat
    tty: true
    volumeMounts:
      - name: jenkins-docker-cfg
        mountPath: /root
        
  volumes:
  - name: jenkins-docker-cfg
    projected:
      sources:
      - secret:
          name: regcred
          items:
            - key: .dockerconfigjson
              path: .docker/config.json
  - name: maven-repo
    persistentVolumeClaim:
      claimName: maven-repo
"""
) {

  node('mypod') {
      stage('Checkout') {
          checkout scm
          //git branch: 'mergeAll', url: 'https://github.com/guigeek123/spring-petclinic-jenkins-kubernetes.git'
      }


      stage('Sonar and Dependency-Check') {

          container('kubectl') {
              //Manage Nexus secret
              sh 'sed -i.bak \"s#NEXUSLOGIN#$(kubectl get secret nexus-admin-pass -o jsonpath="{.data.username}" | base64 --decode)#\" pipeline-tools/maven/maven-custom-settings'
              sh 'sed -i.bak \"s#NEXUSPASS#$(kubectl get secret nexus-admin-pass -o jsonpath="{.data.password}" | base64 --decode)#\" pipeline-tools/maven/maven-custom-settings'
          }

          container('maven') {

              // ddcheck=true will activate dependency-check scan (configured in POM.xml via a profile)
              sh 'mvn -s pipeline-tools/maven/maven-custom-settings clean verify -Dddcheck=true sonar:sonar'
              sh 'mkdir reports && mkdir reports/dependency && cp target/dependency-check-report.xml reports/dependency/'
              // WARNING SECURITY : Change permission to make other container able to move reports in that directory (to be patched)
              sh 'chmod 777 reports'
              publishHTML([allowMissing: false, alwaysLinkToLastBuild: false, keepAll: false, reportDir: 'target/', reportFiles: 'dependency-check-report.html', reportName: 'Dependency-Check Report', reportTitles: ''])
          }


          try {
              withCredentials([string(credentialsId: 'ddtrack_apikey', variable: 'ddtrack_apikey')]) {
                  container('ddtrackcli') {
                      sh('pip install requests')
                      sh("pipeline-tools/dependency-track/scripts/ddtrack-cli.py -k ${env.ddtrack_apikey} -x target/dependency-check-report.xml -p ${project} -u http://ddtrack-service")
                  }
              }
          } catch (org.jenkinsci.plugins.credentialsbinding.impl.CredentialNotFoundException e) {
              println "Export to Dependency Track not activated : please set up the api key in ddtrack_apikey secret"
          }
      }


      stage('Build with Maven') {
          container('maven') {
              sh 'mvn -s pipeline-tools/maven/maven-custom-settings clean deploy -DskipTests'
          }
      }


      stage('Build Docker image with Kaniko') {

          container('maven') {
              sh 'mkdir targetDocker'
              sh 'cd targetDocker && mvn -s ../pipeline-tools/maven/maven-custom-settings org.apache.maven.plugins:maven-dependency-plugin::get -DgroupId=org.springframework.samples -DartifactId=spring-petclinic -Dversion=2.0.0.BUILD-SNAPSHOT -Dpackaging=jar -Ddest=app.jar'
          }

          container(name: 'kaniko', shell: '/busybox/sh'){
              withEnv(['PATH+EXTRA=/busybox']) {
                  sh """#!/busybox/sh
                        /kaniko/executor --dockerfile=Dockerfile -c `pwd` --destination=nexus-direct:8083/${appName}:${env.BUILD_NUMBER} --insecure
                    """
              }
          }

      }

      stage('Scan image with CLAIR') {
          // Execute scan and analyse results
          try {
              container('claircli') {
                  // Prerequisites installation on python image
                  // Could be optimized by providing a custom docker image, built and pushed to github before...
                  sh 'pip install --no-cache-dir -r pipeline-tools/clair/scripts/requirements.txt'

                  // Executing customized Yair script
                  // --no-namespace cause docker image is not pushed withi a "Library" folder in Nexus
                  sh "cd pipeline-tools/clair/scripts/ && chmod +x yair-custom.py && ./yair-custom.py ${appName}:${env.BUILD_NUMBER} --no-namespace"


              }
          } catch (all) {
              // TODO : Show an information on jenkins to say that the gate is not OK but not block the build
          } finally {
              // Move JSON report to be uploaded later in defectdojo
              sh "mkdir reports/clair && mv pipeline-tools/clair/scripts/clair-results.json reports/clair/"
          }

      }


      stage('DAST with ZAP') {

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
                  // Could be optimized by providing a custom docker image, built and pushed to github before...
                  sh 'pip install python-owasp-zap-v2.4'
                  sh 'pip install behave'

                  //Give a chance to app to start
                  //TODO : find a good "wait" method
                  sh 'sleep 30'
                  //Check if the app is available (should show some html source code in logs)
                  sh "curl http://${appName}-frontend-defaultns/"

                  // Executing zap client python scripts
                  sh "cd pipeline-tools/zap/scripts/ && chmod +x pen-test-app.py && ./pen-test-app.py --zap-host zap-proxy-service:8090 --target http://${appName}-frontend-defaultns/"

                  // Publish ZAP Html Report into Jenkins (jenkins plugin required)
                  publishHTML([allowMissing: false, alwaysLinkToLastBuild: false, keepAll: false, reportDir: 'pipeline-tools/zap/scripts/', reportFiles: 'results.html', reportName: 'ZAP full report', reportTitles: ''])

                  // Move XML report to be uploaded later in defectdojo
                  sh "mkdir reports/zap && mv pipeline-tools/zap/scripts/zap-results.xml reports/zap/"

                  // Analysing results using behave
                  sh 'cd pipeline-tools/zap/scripts/ && behave'
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

      try {
          withCredentials([string(credentialsId: 'defectdojo_apikey', variable: 'defectdojo_apikey')]) {
              stage('Upload Reports to DefectDojo') {
                  container('defectdojocli'){
                      sh('pip install requests')
                      sh("cd pipeline-tools/defectdojo/scripts/ && chmod +x dojo_ci_cd.py && ./dojo_ci_cd.py --host http://defectdojo:80 --api_key ${env.defectdojo_apikey} --build_id ${env.BUILD_NUMBER} --user admin --product ${project} --dir ../../../reports/")
                  }
              }
          }

      } catch (org.jenkinsci.plugins.credentialsbinding.impl.CredentialNotFoundException e) {
          println "Export to Defect Dojo not activated : please set up the api key in defectdojo_apikey secret"
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
