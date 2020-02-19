# caasp_robotframework

## Installation

sudo pip install -r requirements.txt
You need to have this tools installed : 
- openldap2-client
- kubectl ( 1.17.3 )
- helm ( 2.16.1 )

## Setup environment
Configure ${CAASP_KEY} in parametes/env.robot by adding your SSC key

Configure cluster.json in workdir/cluster.json by adding the IPs of LB / master / worker

## Execute test

robot --variable VM_USER:sles --test Caasp_Robotframework.Test.Rbac.389ds_authentication  <caasp_robotframework_folder>

## Configuration available

You can change globale variable by adding -v <variablename>:<new value>. Here some usefull variable

- CLUSTER : give a specific name for the cluster directory, if the nn=ame match a running cluster it will use this cluster for the test
- VM_USER : for aws, need to be change for ec2-user
- MODE : 
    - by default use skuba from pattern
    - DEV : will build skuba from github with devel option ( you can also specify a pull request number with PULL_REQUEST )
- SUFFIX : give a suffix to your cluster nodes names, could be your name 