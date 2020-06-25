pipeline {
    agent any
    environment {
        robotenv = credentials('azure')
    }
    stages {
        stage('intialize') {
            steps {
                sh "cp \$robotenv parameters"
                sh 'sudo chmod 0600 data/id_shared'
                sh 'sudo pip install -r requirements.txt'
            }
        }

        stage("Run test") {
            parallel {

                stage('01. Build cluster from pattern on OpenStack') {
                    environment {
                        random1 = "${sh(script: 'python3 $WORKSPACE/lib/generate_random.py', returnStdout: true).trim()}"
                    }
                    steps {
                        sh 'python3 -m robot.run --NoStatusRC --argumentfile $WORKSPACE/argumentfiles/openstack_v5_SP2_release.txt -v CLUSTER:cluster-\$random1 --outputdir reports1 ./'
                        sh 'python3 -m robot.run --NoStatusRC --argumentfile $WORKSPACE/argumentfiles/openstack_v5_SP2_release.txt -v CLUSTER:cluster-\$random1 --rerunfailed reports1/output.xml --outputdir reports ./'
                        sh 'python3 -m robot.rebot --merge --output reports/output.xml -l reports/log.html -r reports/report.html reports1/output.xml reports/output.xml'
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

                stage('02. Build cluster from pattern on VMWARE with CPI activated and use default dns') {
                    environment {
                        random2 = "${sh(script: 'python3 $WORKSPACE/lib/generate_random.py', returnStdout: true).trim()}"
                    }
                    steps {
                        sh 'python3 -m robot.run --NoStatusRC --argumentfile $WORKSPACE/argumentfiles/vmware_v5_SP2_release_CPI_DNS.txt -v CLUSTER:cluster-\$random2 --outputdir reports1 ./'
                        sh 'python3 -m robot.run --NoStatusRC --argumentfile $WORKSPACE/argumentfiles/vmware_v5_SP2_release_CPI_DNS.txt -v CLUSTER:cluster-\$random2 --rerunfailed reports1/output.xml --outputdir reports ./'
                        sh 'python3 -m robot.rebot --merge --output reports/output.xml -l reports/log.html -r reports/report.html reports1/output.xml reports/output.xml'
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

                stage('03. Build cluster from pattern on VMWARE with CPI activated and not use of the default dns') {

                    environment {
                        random3 = "${sh(script: 'python3 $WORKSPACE/lib/generate_random.py', returnStdout: true).trim()}"
                    }
                    steps {
                        sh 'python3 -m robot.run --NoStatusRC --argumentfile $WORKSPACE/argumentfiles/vmware_v5_SP2_release_CPI_NoDNS.txt -v CLUSTER:cluster-\$random3 --outputdir reports1 ./'
                        sh 'python3 -m robot.run --NoStatusRC --argumentfile $WORKSPACE/argumentfiles/vmware_v5_SP2_release_CPI_NoDNS.txt -v CLUSTER:cluster-\$random3 --rerunfailed reports1/output.xml --outputdir reports ./'
                        sh 'python3 -m robot.rebot --merge --output reports/output.xml -l reports/log.html -r reports/report.html reports1/output.xml reports/output.xml'
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
//
//            stage('04. Build cluster on AWS') {
//                steps {
//                    dir("scripts") {
//                        sh(script: 'docker run --rm -v $PWD:/app -v ${VMWARE_ENV_FILE}:/app/env-vmware.conf:ro -e SUFFIX=04-${SUFFIX} -e SCC validator:release -p vmware -n 1:3 -t base -e UPGRADE=after -e INCIDENT_RPM=$INCIDENT_RPM -e INCIDENT_REG=$INCIDENT_REG', label: 'Validator run')
//                    }
//                }
            }

        }
    }

}

