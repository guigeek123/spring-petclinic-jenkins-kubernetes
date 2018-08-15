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

	    /** TODO : Deploy access to target from default namespace (same namespace as ZAP) */
	    /** For now : using a demo app */
	    container('kubectl') {
	        sh 'kubectl apply -f k8s/demo/deployment-frontend.yaml'
	        sh 'kubectl apply -f k8s/demo/service-frontend.yaml'
	    }

	    /** Execute scan and analyse results */
		try {

		    container('zapcli') {
		        /** Prerequisites installation on python image
		        *   Could be optimized by providing a custom docker image, built and pushed to github before... */
			    sh 'pip install python-owasp-zap-v2.4'
			    sh 'pip install behave'

			    /** Executing zap client python scripts */
			    sh 'cd bootstrap-infra/zap/scripts/ && chmod +x pen-test-app.py && ./pen-test-app.py --zap-host zap-proxy-service:8090 --target http://demo-frontend/'

			    /** Analysing results using behave */
			    sh 'cd scripts && behave'
		    }
        } catch (all) {
            /** We do not want to break the build for now */
        }

		/** TODO : Publish ZAP report  */

		/** Disable access from default namespace */
		container('kubectl') {
            sh 'kubectl delete deployment demo-app'
            sh 'kubectl delete service demo-frontend'
        }
	}
	
  }  
  
}
