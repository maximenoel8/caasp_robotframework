*** Settings ***
Resource          ../commands.robot

*** Keywords ***
get top nodes
    ${top_result}    kubectl    top nodes
    [Return]    ${top_result}

get top pods
    ${top_result}    kubectl    top pods -A
    [Return]    ${top_result}

can get cpu/memory for nodes
    ${top result}    get top nodes
    @{lines}    Split To Lines    ${top result}
    @{nodes}    get nodes name from CS
    ${number_of_nodes}    Get Length    ${nodes}
    ${number}    Get Length    ${lines}
    ${number_of_line_top_results}    Evaluate    ${number}-1
    Should Be Equal    ${number_of_line_top_results}    ${number_of_nodes}
    FOR    ${line}    IN    @{lines}
        @{elements}    Split String    ${line}
        Continue For Loop If    "${elements[0]}"=="NAME"
        Should Match Regexp    ${elements[1]}    \\d+m
        Should Match Regexp    ${elements[2]}    \\d{1,2}%
        Should Match Regexp    ${elements[3]}    \\d+Mi
        Should Match Regexp    ${elements[4]}    \\d{1,2}%
    END

can get cpu/memory for pods
    ${top result}    get top pods
    @{lines}    Split To Lines    ${top result}
    FOR    ${line}    IN    @{lines}
        @{elements}    Split String    ${line}
        Continue For Loop If    "${elements[0]}"=="NAMESPACE"
        Should Match Regexp    ${elements[2]}    \\d+m
        Should Match Regexp    ${elements[3]}    \\d+Mi
    END

mestrics is deployed
