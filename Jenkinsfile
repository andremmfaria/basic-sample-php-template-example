import groovy.json.JsonSlurper
pipeline {
    agent { node { label 'docker-build' } }
    
    environment {
      SONAR_CRED = credentials("SONAR_CREDENTIALS")
	    NEXUS_CRED = credentials("NEXUS_CREDENTIALS")
    }

    stages {
        stage('Configuration') {
            steps {
                script {
                    env.SHORT_COMMIT = env.GIT_COMMIT.take(7)
                    switch(env.BRANCH_NAME){
                        case "master":
                            env.RELEASE = "st"
                            break
                        case "develop":
                            env.RELEASE = "dv"
                            break
                        case ~/(feature)\/(.*)/:
                            env.RELEASE = "ft"
                            break
                        case ~/(release|hotfix)\/(.*)/:
                            env.RELEASE = "rc"
                            break
                        default:
                            env.RELEASE = ""
                            break
                    }
					          env.PR_NAME = "${env.JOB_NAME.split('/')[0]}"
                    env.PACKAGE_NAME = "${env.PR_NAME}-${SHORT_COMMIT}-${RELEASE}.tar.gz"
                }
            }
        }

        stage('inform slack') { steps {
            slackSend (color: '#FFFF00', message: ":rocket: STARTED: Job: `${env.JOB_NAME}` \n CONSOLE: ${env.BUILD_URL}console \n GIT URL: ${env.GIT_URL} \n Branch: `${env.BRANCH_NAME}`")
            }
        }
        
        stage('Sonar Test') {
            steps {
                script{
                  WEBHOOK = registerWebhook()
                  def WEBHOOK_URL = "${WEBHOOK.getURL()}"
                  def PROJECT = sh(script: "curl -d 'projects=${env.PR_NAME}:${env.BRANCH_NAME}' -u ${env.SONAR_CRED} $SONARQUBE_SERVER/api/projects/search | jq .components[0].key", returnStdout: true).trim()
                  if(PROJECT.replaceAll('\"','').equalsIgnoreCase("${env.PR_NAME}:${env.BRANCH_NAME}")) { 
                    PROJECT_WEBHOOK_KEY = sh(script: "curl -d 'name=Jenkins&project=${env.PR_NAME}:$BRANCH_NAME&url=${WEBHOOK_URL}' -X POST -u ${env.SONAR_CRED} $SONARQUBE_SERVER/api/webhooks/create | jq -r .webhook.key", returnStdout: true).trim()
                  }
                  else {
                    echo "Project does not exist. Creating..."
                    sh(script: "curl -d 'branch=${env.BRANCH_NAME}&name=${env.PR_NAME}&project=${env.PR_NAME}' -u ${env.SONAR_CRED} $SONARQUBE_SERVER/api/projects/create")
                    PROJECT_WEBHOOK_KEY = sh(script: "curl -d 'name=Jenkins&project=${env.PR_NAME}:$BRANCH_NAME&url=${WEBHOOK_URL}' -X POST -u ${env.SONAR_CRED} $SONARQUBE_SERVER/api/webhooks/create | jq -r .webhook.key", returnStdout: true).trim()
                  }
                }
                sh """
                  /opt/sonar-scanner/bin/sonar-scanner \
                    -Dsonar.sources=. \
                    -Dsonar.projectKey=${env.PR_NAME} \
                    -Dsonar.projectName=${env.PR_NAME} \
                    -Dsonar.projectVersion=${env.SHORT_COMMIT}-${env.RELEASE} \
                    -Dsonar.branch=${env.BRANCH_NAME} \
                    -Dsonar.host.url=$SONARQUBE_SERVER \
                    -Dsonar.login=$SONARQUBE_LOGIN
                """
                script{ 
                  echo "Waiting for SonarQube to finish the scanning"
                  WEBHOOK_DATA = waitForWebhook WEBHOOK
                  def slurper = new JsonSlurper()
                  def result = slurper.parseText(WEBHOOK_DATA)
                  sh(script: "curl -d 'webhook=$PROJECT_WEBHOOK_KEY' -X POST -u ${env.SONAR_CRED} http://$SONARQUBE_SERVER/api/webhooks/delete". returnStdout: true).trim()
                  echo result.qualityGate.status
                  if ( result.qualityGate.status != "OK") {
                    error("THE CODE WAS NOT APPROVED BY SONARQUBE, GO CHECK")
                  }
                }
            }
        }
		
		    stage('Put to Nexus') {
            steps {
                sh """
                    rm -rf .git .gitignore Jenkinsfile README.md && \
                    tar -czvf ${env.PACKAGE_NAME} ${env.WORKSPACE}/* && \
                    curl -v -k -u ${env.NEXUS_CRED} \
                      --upload-file ${env.WORKSPACE}/${env.PACKAGE_NAME} \
                      ${env.NEXUS_ADDRESS}/${env.JOB_NAME}/${env.PACKAGE_NAME}
                """
            }
        }
        
        /*stage('Deploy') {
            when { anyOf { branch 'master' } }
            steps {
                sshagent (credentials: ['jenkins-mercury-server']) {
                    sh """
                        ssh \
                          -o StrictHostKeyChecking=no \
                          -l root 10.105.103.34 \
                          -p 2222 \
                          git \
                          --work-tree=/var/www/multiplik \
                          --git-dir=/var/www/multiplik/.git \
                          pull origin master
                    """
                }
            }
        }*/
    }
    post {
       success {
             slackSend (color: '#00FF00', message: ":heavy_check_mark: SUCCESSFUL: Job `${env.JOB_NAME}` \n CONSOLE: ${env.BUILD_URL}console \n GIT URL: ${env.GIT_URL} \n Branch: `${env.BRANCH_NAME}`")
        }
        failure {
             slackSend (color: '#FF0000', message: ":heavy_multiplication_x: FAILED:  Job `${env.JOB_NAME}` \n CONSOLE: ${env.BUILD_URL}console \n GIT URL: ${env.GIT_URL} \n Branch: `${env.BRANCH_NAME}`")
        }
    }
}
