# caasp_robotframework

## Installation

sudo pip install -r requirements.txt
You need to have this tools install : 
- openldap2-client
- kubectl
- helm

## Setup environment
Configure ${CAASP_KEY} in parametes/env.robot by adding your SSC key

Configure cluster.json in workdir/cluster.json by adding the IPs of LB / master / worker

## Execute test

robot --variable VM_USER:sles --test Caasp_Robotframework.Test.Rbac.389ds_authentication  <caasp_robotframework_folder>