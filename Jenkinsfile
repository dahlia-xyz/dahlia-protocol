def redeployProjects(String deploymentsString, String namespace, String link) {
  Collection deployments = deploymentsString.split(' ')
  deployments.each { project ->
      // Modify the workload path according to your project naming convention
      String workloadPath = "${link}:${namespace}:${project}" as String
      echo "Deploying ${project} in ${workloadPath}"
      rancherRedeploy alwaysPull: true, images: '', credential: 'RANCHER_TOKEN', workload: workloadPath
  }
}

static Boolean isMainBranch(String branchName) {
  return branchName == 'dev' || branchName == 'beta' || branchName == 'prod' || branchName == 'jenkins'
}

Boolean shouldBundle() {
  def commitMessage = sh(returnStdout: true, script: 'git log -1 --pretty=%B').trim()
  print commitMessage
  String branchName = env.BRANCH_NAME
  return commitMessage.contains('bundletest') || isMainBranch(branchName)
}


String getBundleSuffix() {
  if (env.BRANCH_NAME == "beta") {
    return "beta"
  } else if (env.BRANCH_NAME == "prod") {
    return "prod"
  } else {
    return "dev"
  }
}

def buildDockerImage(String projects, String path, String dockerfile) {
  if (shouldBundle()) {
    sh """
for i in ${projects}; do \
echo "-t \$IMAGE_PATH/\$i:${getBundleSuffix()} "; \
done | \
xargs docker buildx build --pull \
${dockerfile} \
--build-arg GITHUB_SHA=${env.GIT_SHA} \
--build-arg BRANCH_NAME=${env.BRANCH_NAME} \
${path}
"""
  } else {
    sh "docker buildx build ${dockerfile} ${path}"
  }
}

def pushDockerImage(String projects) {
  sh """
     for i in ${projects}; do \
        docker push --all-tags \$IMAGE_PATH/\$i; \
     done
"""
}

pipeline {
    options {
//     disableConcurrentBuilds();
        buildDiscarder(logRotator(artifactDaysToKeepStr: '', artifactNumToKeepStr: '', daysToKeepStr: '5', numToKeepStr: '5'))
    }
    environment {
        GIT_SHA = "${sh(returnStdout: true, script: 'echo ${GIT_COMMIT} | cut -c1-12').trim()}"
        IMAGE_PATH = 'goharbor.goharbor.svc.cluster.local:80/dahlia'
    }
    agent {
        node {
            label 'debian1'
        }
    }
    stages {
        stage('Install') {
            parallel {
                stage('pnpm install') {
                    steps {
                        sh 'pnpm install --frozen-lockfile --unsafe-perm'
                        sh 'git submodule update --init --recursive'
                        sh 'cd lib/royco && git submodule deinit lib/solady && git submodule deinit lib/solmate && git submodule deinit lib/openzeppelin-contracts'
                    }
                }
                stage('Debug') {
                    steps {
                        sh 'node --version'
                        sh 'npm --version'
                        sh 'pnpm --version'
                        sh 'pre-commit --version'
                        sh 'printenv'
                        script {
                            def branchName = sh(returnStdout: true, script: 'git rev-parse --abbrev-ref HEAD').trim()
                            echo "The current branch name is: ${branchName}"
                            echo "GIT_SHA is: ${GIT_SHA}"
                        }
                    }
                }
                stage('Docker Login') {
                    steps {
                        withCredentials([usernamePassword(credentialsId: 'harbor-token', usernameVariable: 'HARBOR_ROBOT_USER', passwordVariable: 'HARBOR_ROBOT_USER_TOKEN')]) {
                            sh 'docker login -u "${HARBOR_ROBOT_USER}" --password "${HARBOR_ROBOT_USER_TOKEN}" ${IMAGE_PATH}'
                        }
                    }
                }
            }
        }
        stage('Build and Lint') {
            parallel {
                stage('Lint') {
                    steps {
                        withCredentials([string(credentialsId: 'MAINNET_RPC_URL', variable: 'MAINNET_RPC_URL'),
                                         string(credentialsId: 'SEPOLIA_RPC_URL', variable: 'SEPOLIA_RPC_URL')]) {
                            script {
                                sh 'pnpm run lint'
                                sh 'pnpm run size'
                            }
                        }
                    }
                }
//                stage('Coverage') {
//                    steps {
//                        withCredentials([string(credentialsId: 'MAINNET_RPC_URL', variable: 'MAINNET_RPC_URL'),
//                                         string(credentialsId: 'SEPOLIA_RPC_URL', variable: 'SEPOLIA_RPC_URL')]) {
//                            script {
//                                sh 'pnpm run coverage'
//                            }
//                        }
//                    }
//                }
                stage('Diff') {
                    steps {
                        withCredentials([string(credentialsId: 'MAINNET_RPC_URL', variable: 'MAINNET_RPC_URL'),
                                         string(credentialsId: 'SEPOLIA_RPC_URL', variable: 'SEPOLIA_RPC_URL')]) {
                            script {
                                sh 'pnpm run diff'
                            }
                        }
                    }
                }
                stage('Debug') {
                    steps {
                        withCredentials([string(credentialsId: 'MAINNET_RPC_URL', variable: 'MAINNET_RPC_URL'),
                                         string(credentialsId: 'SEPOLIA_RPC_URL', variable: 'SEPOLIA_RPC_URL')]) {
                            script {
                                sh 'forge test -vvvv'
                            }
                        }
                    }
                }
//                stage('Coverage') {
//                    steps {
//                        withCredentials([string(credentialsId: 'MAINNET_RPC_URL', variable: 'MAINNET_RPC_URL'),
//                                         string(credentialsId: 'SEPOLIA_RPC_URL', variable: 'SEPOLIA_RPC_URL')]) {
//                            script {
//                                sh 'forge coverage --no-match-coverage=.s.sol --ir-minimum --report lcov'
//                                cobertura(autoUpdateHealth: false, autoUpdateStability: false, coberturaReportFile: 'lcov.info')
//                            }
//                        }
//                    }
//                }
            }
        }
    }
}
