#!/bin/bash

export $(cat /root/.env | xargs)


source $HOME/binaries/tapscripts/extract-and-take-input.sh


function createAKSCluster () {

    printf "\n\nDownloading Azure scripts....\n\n"
    $HOME/binaries/scripts/download-common-scripts.sh clouds.azure scripts/clouds/azure
    sleep 2
    printf "DOWNLOAD COMPLETE...\n"
    
    source $HOME/binaries/scripts/clouds/azure/azure.sh
    prepareAccount || returnOrexit || exit 1


    if [ -z "$AZ_TENANT_ID" ] || [ -z "$AZ_APP_ID" ] || [ -z "$AZ_APP_CLIENT_SECRET" ] || [ -z "$AZ_GROUP_NAME" ] || [ -z "$AZ_LOCATION" ] || [ -z "$AZ_AKS_CLUSTER_NAME" ] || [ -z "$AZ_AKS_VM_SIZE" ] || [ -z "$AZ_AKS_NODE_COUNT" ]
    then
        printf "\n\nNo AZ config found.\nGoing to collect from user and save it in .env for future use....\n\n"
        cp $HOME/binaries/templates/az-aks-variables.template /tmp/az-aks-variables.env.tmp || exit 1
        extractVariableAndTakeInput /tmp/az-aks-variables.env.tmp || exit 1
        export $(cat /root/.env | xargs)
    fi




    ISAZLOGGEDIN=$(az account show | grep name)
    if [ -z "$ISAZLOGGEDIN" ]
    then
        printf "\n\nlogin to az\n\n"
        if [ -z "$AZ_TENANT_ID" ] || [ -z "$AZ_APP_ID" ] || [ -z "$AZ_APP_CLIENT_SECRET" ]
        then
            printf "\n\naz login\n\n"
            az login
        else
            printf "\n\naz login --service-principal --username $AZ_APP_ID --password $AZ_APP_CLIENT_SECRET --tenant $AZ_TENANT_ID\n\n"
            az login --service-principal --username $AZ_APP_ID --password $AZ_APP_CLIENT_SECRET --tenant $AZ_TENANT_ID
        fi
        printf "\n\nLogged with below details\n"
        az account show
    else
        printf "\n\nAlready logged with below details\n"
        az account show
    fi

    ISAZLOGGEDIN=$(az account show | grep name)
    if [ -z "$ISAZLOGGEDIN" ]
    then
        printf "\nERROR:Login unsuccessfull\n"
        exit 1
    fi

    isexists=$(az group show --name ${AZ_GROUP_NAME} | jq -r '.id')
    if [[ -z $isexists ]]
    then
        printf "\nResource group not found with name: ${AZ_GROUP_NAME} in location: ${AZ_LOCATION}. Creating new...\n"
        az group create -l ${AZ_LOCATION} -n ${AZ_GROUP_NAME}
    fi

    printf "\nAdd pod security policies support preview (required for learningcenter)\n"
    az extension add --name aks-preview
    az provider register --namespace Microsoft.ContainerService
    az feature register --name PodSecurityPolicyPreview --namespace Microsoft.ContainerService
    # Wait until the status is "Registered"
    isregistered='not'
    count=1
    while [[ $isregistered == 'Registered' && $count -lt 15 ]]; do
        printf "\nWaiting for 1m before checking status is 'Registered' for Microsoft.ContainerService/PodSecurityPolicyPreview...(try #$count of 15)\n"
        sleep 1m
        isregistered=$(az feature list  --query "[?contains(name, 'Microsoft.ContainerService/PodSecurityPolicyPreview')].{state:properties.state}" | jq -r '.[] | select(.state == "Registered") | .state')
        ((count=$count+1))
    done

    printf "\nCreate aks cluster in rg:${AZ_GROUP_NAME} name:${AZ_AKS_CLUSTER_NAME} of nodesize:${AZ_AKS_VM_SIZE} with nodecount:${AZ_AKS_NODE_COUNT}\n"
    az aks create --resource-group ${AZ_GROUP_NAME} --name ${AZ_AKS_CLUSTER_NAME} --node-count ${AZ_AKS_NODE_COUNT} --node-vm-size ${AZ_AKS_VM_SIZE} --enable-pod-security-policy --generate-ssh-keys #--node-osdisk-size 500 #--enable-addons monitoring

    printf "\naks cluster get credential. This should create /root/.kube/config file...\n"
    az aks get-credentials --resource-group ${AZ_GROUP_NAME} --name ${AZ_AKS_CLUSTER_NAME}

    printf "\ncreating clusterrolebinding:tap-psp-rolebinding --group=system:authenticated --clusterrole=psp:privileged...\n"
    kubectl create clusterrolebinding tap-psp-rolebinding --group=system:authenticated --clusterrole=psp:privileged

    printf "\nCOMPLETE\n\n\n"
}