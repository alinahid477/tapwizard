#!/bin/bash


export $(cat /root/.env | xargs)

isreturnorexit='n'
returnOrexit()
{
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
    then
        isreturnorexit='return'
        return 1
    else
        isreturnorexit='exit'
        exit 1
    fi
}


source $HOME/binaries/scripts/extract-and-take-input.sh


createDevNS () {
    printf "\n*******Starting developer namespace wizard*******\n\n"

    unset namespacename
    while [[ -z $namespacename ]]; do
        read -p "name of the namespace: " namespacename
        if [[ -z $namespacename && ! $namespacename =~ ^[A-Za-z0-9_\-]+$ ]]
        then
            printf "empty or invalid value is not allowed.\n"
        fi
    done

    printf "\nChecking namcespace in the cluster....\n"
    isexist=$(kubectl get ns | grep "^$namespacename")

    if [[ -n $isexist ]] 
    then
        printf "namespace: $namespacename already exists....Skipping Create New\n"
    else
        printf "namespace: $namespacename does not exist, Creating New...."
        kubectl create ns $namespacename && printf "OK" || printf "FAILED"
        printf "\n"

        isexist=$(kubectl get ns | grep "^$namespacename")
        if [[ -z $isexist ]]
        then
            printf "ERROR: Failed to create namespace: $namespacename\n"
            returnOrexit || return 1
        fi
    fi

    tmpCmdFile=/tmp/devnamespacecmd.tmp
    cmdTemplate="tanzu secret registry add registry-credentials --server <PVT_REGISTRY_SERVER> --username <PVT_REGISTRY_USERNAME> --password <PVT_REGISTRY_PASSWORD> --yes --namespace ${namespacename}"

    echo $cmdTemplate > $tmpCmdFile
    extractVariableAndTakeInput $tmpCmdFile
    cmdTemplate=$(cat $tmpCmdFile)

    printf "\nCreating new secret for private registry with name: registry-credentials..."
    $(echo $cmdTemplate) && printf "OK" || printf "FAILED"
    printf "\n"

    printf "\nCreating RBAC, SA for associating TAP and registry with name: default..."
    kubectl apply -n $namespacename -f $HOME/binaries/templates/workload-ns-setup.yaml && printf "OK" || printf "FAILED"
    printf "\n"

    printf "\n\n**** Developer namespace: $namespacename setup...COMPLETE\n\n\n"
}



createDevNS