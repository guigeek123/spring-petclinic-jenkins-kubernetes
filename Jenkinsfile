def project = 'kubepetclinic'
def  appName = 'petclinic'
def  feSvcName = "${appName}-frontend"
def  imageTag = "gcr.io/${project}/${appName}:${env.BUILD_NUMBER}"

podTemplate(serviceAccount:'cd-jenkins', label: 'mypod', containers: [
  //containerTemplate(name: 'maven', image: 'maven:alpine', ttyEnabled: true, command: 'cat'),
  //containerTemplate(name: 'gcloud', image: 'gcr.io/cloud-builders/gcloud', ttyEnabled: true, command: 'cat'),
  //containerTemplate(name: 'kubectl', image: 'gcr.io/cloud-builders/kubectl', ttyEnabled: true, command: 'cat'),
  //containerTemplate(name: 'zapcli', image: 'python', ttyEnabled: true, command: 'cat'),
  containerTemplate(name: 'defectdojocli', image: 'python:2.7', ttyEnabled: true, command: 'cat')
  ], volumes: [
	emptyDirVolume(mountPath: '/root/.m2/repository', memory: false)
  ]) {

  node('mypod') {

      parameters {
          stringParam("DefectDojo API Key", "", "API Key for DefectDojo")
          //text(defaultValue: true, description: 'API Key for DefectDojo', name: 'defectdojo_apikey')
      }


      stage('Checkout') {
          checkout scm
      }

      stage('Upload Reports to DefectDojo') {
          container('defectdojocli'){
              sh('pip install requests')
              //TODO : check if pythonpath is not required
              //TODO : script to create the product in defectdojo
              //sh("cd bootstrap-infra/defectdojo/scripts/ && chmod +x createProductInDefectDojo.py && ./createProductInDefectDojo.py --api_key ${env.defectdojo_apikey} --product_name ????? --user admin --host http://defectdojo:80")
              sh("cd bootstrap-infra/defectdojo/scripts/ && chmod +x dojo_ci_cd.py && ./dojo_ci_cd.py --host http://defectdojo:80 --api_key ${env.defectdojo_apikey} --build_id ${env.BUILD_NUMBER} --user admin --product 1 --dir reportsdemo/")

          }
      }

  }  

}
