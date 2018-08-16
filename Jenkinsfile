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
	
	stage('Check ZAP results') {

	    /**
	    * TODO :
	    * - deploy.sh :
	    *   OK - Create a dedicated 'testing' namespace for DAST testing
	    *   OK - Deploy ZAP service into default namespace
	    * - Jenkinsfile :
	    *   PENDING - Deploy application (deployment + Service) into the testing namespace during those test (dynamic replacement of namespace name and service type in yaml files ?)
	    *   OK      - Deploy an internamespace service to make the application accessible from default namespace, where ZAP and jenkins are running
	    *   OK      - Use a dynamic parameter for the when executing pen-test-app scripts : use the name of the service deployed above...
	    *   TODO    - Add functions to create / load a zap session (simpler way : create new unique session at each build ; better way : learn to use zap iteratively in the same zap session...)
	    *   TODO    - Add functions for detailed zap configuration : push and load zap context files...
	    */

	    // For now : using a demo app
	    container('kubectl') {

	        // Create dedicated deployment yaml for testing in order not to be confused later with deployment in production
	        sh 'mkdir ./k8s/testing/'
	        sh 'cp ./k8s/production/frontend.yaml k8s/testing/'
	        sh 'cp ./k8s/services/frontend.yaml k8s/testing/frontend-service.yaml'

	        // Deploy to testing namespace, with the docker image created before
	        // TODO : remplacer nginxdemos/hello par ${imageTag} ci-dessous et virer l'autre ligne
	        sh("sed -i.bak 's#gcr.io/kubepetclinic/petclinic:37#nginxdemos/hello#' ./k8s/testing/*.yaml")
            sh("sed -i.bak 's#8080#80#' ./k8s/testing/frontend-service.yaml")
            // TODO : fin de la partie à editer
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

			    // Publish ZAP Html Report into Jenkins
                publishHTML([allowMissing: false, alwaysLinkToLastBuild: false, keepAll: false, reportDir: 'bootstrap-infra/zap/scripts/', reportFiles: 'results.html', reportName: 'ZAP full report', reportTitles: ''])

			    // Analysing results using behave
			    sh 'cd bootstrap-infra/zap/scripts/ && behave'
		    }
        } catch (all) {
            // We do not want to break the build for now
        }

		// Destroy app from testing namespace
		container('kubectl') {
		    sh "kubectl delete service ${appName}-frontend-defaultns"
            sh "kubectl delete deployment ${appName}-frontend-deployment --namespace=testing"
            sh "kubectl delete service ${appName}-frontend --namespace=testing"
        }
	}
	
  }  
  
}
