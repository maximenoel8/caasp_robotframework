*** Settings ***
Library           ../lib/yaml_editor.py

*** Keywords ***
389ds server installed
    Modify Add Value    workdir/file.yaml    items 0 quantity    4
