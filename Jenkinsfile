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
					
                    env.PACKAGE_NAME = "${env.JOB_NAME.split('/')[0]}-${SHORT_COMMIT}-${RELEASE}.tar.gz"
                }
            }
        }

        stage('inform slack') {
          steps {
            slackSend (color: '#FFFF00', message: ":rocket: STARTED: Job: `${env.JOB_NAME}` \n CONSOLE: ${env.BUILD_URL}console \n GIT URL: ${env.GIT_URL} \n Branch: `${env.BRANCH_NAME}`")
            }
        }
        
        stage('Sonar Test') {
            steps {
                sh """
                  /opt/sonar-scanner/bin/sonar-scanner \
                    -Dsonar.sources=. \
                    -Dsonar.projectKey=${env.JOB_NAME.split('/')[0]} \
                    -Dsonar.projectName=${env.JOB_NAME.split('/')[0]} \
                    -Dsonar.projectVersion=${env.SHORT_COMMIT}-${env.RELEASE} \
                    -Dsonar.branch=${env.BRANCH_NAME} \
                    -Dsonar.host.url=$SONARQUBE_SERVER \
                    -Dsonar.login=$SONARQUBE_LOGIN
                """
                script{ 
                  WEBHOOK = registerWebhook()
                  def WEBHOOK_URL = "${WEBHOOK.getURL()}"
                  def PROJECT_WEBHOOK_KEY = sh(script: "curl -d 'name=Jenkins&project=${env.JOB_NAME.split('/')[0]}:$BRANCH_NAME&url=${WEBHOOK_URL}' -X POST -u ${env.SONAR_CRED} $SONARQUBE_SERVER/api/webhooks/create | jq -r .webhook.key", returnStdout: true).trim()
                  echo "Waiting for SonarQube to finish the scanning"
                  WEBHOOK_DATA = waitForWebhook WEBHOOK
                  echo "Passed0!"
                  def slurper = new JsonSlurper()
                  echo "Passed1!"
                  def result = slurper.parseText(WEBHOOK_DATA)
                  echo "Passed2!"
                  def result = slurper.parseText(WEBHOOK_DATA)
                  sh("curl -d 'webhook=$PROJECT_WEBHOOK_KEY' -X POST http://$SONARQUBE_LOGIN@$SONARQUBE_SERVER/api/webhooks/delete")
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
