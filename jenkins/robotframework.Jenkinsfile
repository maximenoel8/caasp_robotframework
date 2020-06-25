pipeline {
    agent {
        any
    }
    environment {
    }
    stages {
        stage('intialize') {
            steps {
                withCredentials([file(credentialsId: 'env.robot', variable: 'robotenv')])
                        {
                            sh "cp \$robotenv parameters"
                        }
                sh 'sudo chmod 0600 data/id_shared'
                sh 'sudo pip install -r requirements.txt'
            }
        }
    }
}

stage('Run Robot Tests') {
    steps {
        sh 'python3 -m robot.run --NoStatusRC --argumentfile $WORKSPACE/argumentfiles/vmware_v5_SP2_release_CPI_DNS.txt --outputdir reports ./'
//        sh 'python3 -m robot.run --NoStatusRC --variable SERVER:${CT_SERVER} --rerunfailed reports1/output.xml --outputdir reports myapp/uiTest/testCases/smokeSuite/'
//        sh 'python3 -m robot.rebot --merge --output reports/output.xml -l reports/log.html -r reports/report.html reports1/output.xml reports/output.xml'
        sh 'exit 0'
    }
    post {
        always {
            script {
                step(
                        [
                                $class              : 'RobotPublisher',
                                outputPath          : 'reports',
                                outputFileName      : '**/output.xml',
                                reportFileName      : '**/report.html',
                                logFileName         : '**/log.html',
                                disableArchiveOutput: false,
                                passThreshold       : 50,
                                unstableThreshold   : 40,
                                otherFiles          : "**/*.png,**/*.jpg",
                        ]
                )
            }
        }
    }
}


