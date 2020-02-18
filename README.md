# caasp_robotframework

## Installation

sudo pip install -r requirements.txt

## Setup environment
Configure ${CAASP_KEY} in parametes/env.robot by adding your SSC key

Configure cluster.json in workdir/cluster.json by adding the IPs of LB / master / worker

## Execute test

robot --variable VM_USER:sles --test Caasp_Robotframework.Test.Rbac.389ds_authentication  <caasp_robotframework_folder>