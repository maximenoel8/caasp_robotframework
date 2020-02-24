# caasp_robotframework

## Installation

sudo pip install -r requirements.txt
You need to have this tools installed : 
- openldap2-client
- kubectl ( 1.17.3 )
- helm ( 2.16.1 )
- custom terraform 0.11 ( from caasp pattern )

## Setup environment
Configure ${CAASP_KEY} in parametes/env.robot by adding your SSC key
Configure your vmware and openstack setting in env.robot


## Execute test

```
robot -v PREFIX:<your name> -v NUMBER:<master:worker> -v PLATFORM:<openstack|vmware> --test <path to your test>  <caasp_robotframework_folder>
```

*Exemple:*
 ```
robot --test Caasp\ Robotframework.Test.Rbac.389ds_authentication -v NUMBER:1:3 -v PLATFORM:vmware -v PREFIX:mnoel --outputdir=tmp .
```
*More advance example :*
```
robot --test Caasp\ Robotframework.Test.Replica.dex_gangway_replicat -v MODE:DEV --variable PULL_REQUEST:951 -v PREFIX:mnoel -v NUMBER:1:3 -v PLATFORM:vmware --outputdir=tmp .
```

## Configuration available

You can change global variable by adding -v <variablename>:<new value>. Here some usefull variable

- CLUSTER : give a specific name for the cluster directory, if the nn=ame match a running cluster it will use this cluster for the test
- VM_USER : for aws, need to be change for ec2-user
- MODE : 
    - by default use skuba from pattern
    - DEV : will build skuba from github with devel option ( you can also specify a pull request number with PULL_REQUEST )
- PREFIX : give a suffix to your cluster nodes names, could be your name
- NUMBER : number of master and worker for the test separated by `:` 
- PLATFORM : (vmware|openstack) specify a platform where to run the test 