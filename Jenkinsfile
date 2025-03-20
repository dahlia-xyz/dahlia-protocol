pipeline {
    options {
        buildDiscarder(logRotator(artifactDaysToKeepStr: '', artifactNumToKeepStr: '', daysToKeepStr: '5', numToKeepStr: '5'))
    }
    environment {
        GIT_SHA = "${sh(returnStdout: true, script: 'echo ${GIT_COMMIT} | cut -c1-12').trim()}"
        ARBITRUM_RPC_URL = 'https://1rpc.io/arb'
        BERACHAIN_RPC_URL = 'https://rpc.berachain.com/'
        CARTIO_RPC_URL = 'https://teddilion-eth-cartio.berachain.com'
        MAINNET_RPC_URL = 'https://ethereum-rpc.publicnode.com'
        SEPOLIA_RPC_URL = 'https://app.dahliadev.xyz/rpc/evm/42161'
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
//                        sh 'cd lib/royco && git submodule deinit lib/solady && git submodule deinit lib/solmate && git submodule deinit lib/openzeppelin-contracts'
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
            }
        }
        stage('Build and Lint') {
            parallel {
                stage('Lint') {
                    steps {
                        script {
                            sh 'pnpm run diff'
                            sh 'forge test -vvvv'
                            sh 'pnpm run lint'
                            sh 'pnpm run size'
                        }
                    }
                }
            }
        }
    }
}
