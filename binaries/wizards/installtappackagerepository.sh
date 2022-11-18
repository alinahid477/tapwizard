#!/bin/bash


export $(cat $HOME/.env | xargs)

source $HOME/binaries/scripts/returnOrexit.sh


installTapPackageRepository()
{
    export $(cat /root/.env | xargs)

    printf "\n\n\n********* Checking pre-requisites *************\n\n\n"
    sleep 1
    printf "\nChecking Access to Tanzu Net..."
    if [[ -z $INSTALL_REGISTRY_USERNAME || -z $INSTALL_REGISTRY_PASSWORD ]]
    then
        printf "\nERROR: Tanzu Net username or password missing.\n"
        returnOrexit || return 1
    fi
    sleep 1
    printf "COMPLETED.\n\n"
    # printf "\nChecking Cluster Specific Registry...\n"
    # if [[ -z $PVT_REGISTRY || -z $PVT_REGISTRY_USERNAME || -z $PVT_REGISTRY_PASSWORD ]]
    # then
    #     printf "\nERROR: Access information to container registry is missing.\n"
    # fi
    
    local isexist=$(which kapp)
    if [[ -z $isexist ]]
    then
        printf "\nERROR: kapp not found, meaning cluster essential has not been installed.\n"
        returnOrexit || return 1
    fi
    isexist=$(which tanzu)
    if [[ -z $isexist ]]
    then
        printf "\nERROR: tanzu cli not found, meaning it has not been installed.\n"
        returnOrexit || return 1
    fi
        
    if [[ -z $INSTALL_TANZU_CLUSTER_ESSENTIAL || $INSTALL_TANZU_CLUSTER_ESSENTIAL != 'COMPLETED' ]]
    then
        source $HOME/binaries/scripts/install-cluster-essential.sh
        installClusterEssential
        local ret=$?
        if [[ $ret == 1 ]]
        then
            printf "\nERROR: TANZU CLUSTER ESSENTIAL installation failed.\n"
            returnOrexit || return 1
        fi
        sleep 2
    fi
    

    local confirmed=''
    while true; do
        read -p "Confirm to install tap-repository? [y/n]: " yn
        case $yn in
            [Yy]* ) confirmed='y'; printf "you confirmed yes\n"; break;;
            [Nn]* ) confirmed='n'; printf "You said no.\n\nExiting...\n\n"; break;;
            * ) echo "Please answer y or n.";;
        esac
    done

    if [[ $confirmed == 'n' ]]
    then
        printf "\nNot proceed further...\n"
        returnOrexit || return 1
    fi

    printf "\nChecking PSP:vmware-system-privileged in the cluster..."
    local isvmwarepsp=$(kubectl get psp | grep -w vmware-system-privileged)
    local istmcpsp=$(kubectl get psp | grep -w vmware-system-tmc-privileged)
    if [[ -n $isvmwarepsp || -n $istmcpsp ]]
    then
        printf "FOUND\n"
        printf "\nChecking clusterrolebinding:default-tkg-admin-privileged-binding in the cluster..."
        local isclusterroleexist=$(kubectl get clusterrolebinding -A | grep -w default-tkg-admin-privileged-binding)
        if [[ -z $isclusterroleexist ]]
        then
            
            if [[ -n $isvmwarepsp ]]
            then
                printf "NOT FOUND. Creating for psp:vmware-system-privileged...."
                kubectl create clusterrolebinding default-tkg-admin-privileged-binding --clusterrole=psp:vmware-system-privileged --group=system:authenticated
                printf "clusterrolebinding:default-tkg-admin-privileged-binding....CREATED.\n"
            fi
            # if [[ -n $istmcpsp ]]
            # then
            #     printf "NOT FOUND. Creating for psp:vmware-system-privileged...."
            #     kubectl create clusterrolebinding default-tkg-admin-privileged-binding --clusterrole=psp:vmware-system-privileged --group=system:authenticated
            #     printf "clusterrolebinding:default-tkg-admin-privileged-binding....CREATED.\n"
            # fi
        else
            printf "FOUND.\n"
        fi
    fi

    isexist=$(kubectl get ns | grep "^tap-install")
    if [[ -z $isexist ]]
    then
        printf "\nCreate namespace tap-install in k8s..."
        kubectl create ns tap-install
        printf "\n....COMPLETE\n\n"
    fi
    
    printf "\nStarting image relocation for tap installation...\n"
    isexist=$(imgpkg version)
    if [[ -z $isexist ]]
    then
        printf "\nERROR: imgpgk is missing. This tool is required for image relocation.\n"
        returnOrexit || return 1
    fi
    # PATCH: Dockerhub is special case
    # This patch is so that 
    local myregistryserver=$PVT_REGISTRY_SERVER
    if [[ -n $PVT_REGISTRY_SERVER && $PVT_REGISTRY_SERVER =~ .*"index.docker.io".* ]]
    then
        myregistryserver="index.docker.io"        
    fi
    printf "\ndocker login to registry.tanzu.vmware.com...\n"
    docker login registry.tanzu.vmware.com -u ${INSTALL_REGISTRY_USERNAME} -p ${INSTALL_REGISTRY_PASSWORD} && printf "DONE.\n"
    sleep 1
    printf "\ndocker login to ${myregistryserver}/${PVT_REGISTRY_INSTALL_REPO}...\n"
    docker login ${myregistryserver} -u ${PVT_REGISTRY_USERNAME} -p ${PVT_REGISTRY_PASSWORD} && printf "DONE.\n"
    sleep 2
    printf "\nExecuting imgpkg copy...\n"
    imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:${TAP_VERSION} --to-repo ${myregistryserver}/${PVT_REGISTRY_INSTALL_REPO} && printf "\n\nCOPY COMPLETE.\n\n";



    printf "\nCreate a registry secret for ${PVT_REGISTRY_SERVER}...\n"
    tanzu secret registry add tap-registry --username ${PVT_REGISTRY_USERNAME} --password ${PVT_REGISTRY_PASSWORD} --server ${myregistryserver} --export-to-all-namespaces --yes --namespace tap-install
    printf "\n...COMPLETE\n\n"

    printf "\nCreate tanzu-tap-repository...\n"
    tanzu package repository add tanzu-tap-repository --url ${PVT_REGISTRY_SERVER}/${PVT_REGISTRY_INSTALL_REPO}:${TAP_VERSION} --namespace tap-install

    printf "\nWaiting 3m before checking...\n"
    sleep 3m
    printf "\nChecking tanzu-tap-repository status...\n"
    tanzu package repository get tanzu-tap-repository --namespace tap-install
    printf "\nDONE\n\n"

    printf "Extracting latest tap package version in 10s..."
    sleep 10s
    TAP_PACKAGE_VERSION=$(tanzu package available list tap.tanzu.vmware.com --namespace tap-install -o json | jq -r '[ .[] | {version: .version, released: .["released-at"]|split(" ")[0]} ] | sort_by(.released) | reverse[0] | .version')
    printf "$TAP_PACKAGE_VERSION"

    sed -i '/TAP_PACKAGE_VERSION/d' $HOME/.env
    printf "\nTAP_PACKAGE_VERSION=$TAP_PACKAGE_VERSION" >> $HOME/.env
    sleep 1
    sed -i '/INSTALL_TAP_PACKAGE_REPOSITORY/d' $HOME/.env
    printf "\nINSTALL_TAP_PACKAGE_REPOSITORY=COMPLETED\n" >> $HOME/.env
    export INSTALL_TAP_PACKAGE_REPOSITORY=COMPLETED

    printf "\nListing available packages in 20s...\n"
    sleep 20s
    tanzu package available list --namespace tap-install
    printf "\nDONE\n\n"
}




