*** Settings ***
Suite Teardown    teardown_suite
Test Setup        Setup environment
Test Teardown     teardown_test
Resource          ../function/skuba_tool_install.robot
Resource          ../function/setup_environment.robot
Resource          ../function/infra_setup/common.robot
