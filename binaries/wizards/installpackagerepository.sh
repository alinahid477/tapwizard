#!/bin/bash


export $(cat $HOME/.env | xargs)

source $HOME/binaries/scripts/returnOrexit.sh
source $HOME/binaries/scripts/install-cluster-essential.sh
source $HOME/binaries/scripts/install-tanzu-cli.sh

installPackageRepository()
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
    


    unset performinstall
    if [[ -n $INSTALL_TANZU_CLUSTER_ESSENTIAL && $INSTALL_TANZU_CLUSTER_ESSENTIAL == 'COMPLETED' ]]
    then
        printf "\nFound tanzu-cluster-essential installation is marked as complete\n"
        while true; do
            read -p "Do you want to trigger deployment again? [y/n]: " yn
            case $yn in
                [Yy]* ) performinstall="y"; printf "you confirmed yes\n"; break;;
                [Nn]* ) performinstall="n";printf "You said no.\n"; break;;
                * ) echo "Please answer y or n.";;
            esac
        done
    else
        performinstall='y'
    fi
    if [[ $performinstall == 'y' ]]
    then
        printf "\nInstalling cluster essential in k8s cluster...\n\n"
        sleep 1
        cd $HOME/tanzu-cluster-essentials
        source ./install.sh
        printf "\nTanzu cluster essential instllation....COMPLETED\n\n"
    fi
    if [[ -z $INSTALL_TANZU_CLUSTER_ESSENTIAL ]]
    then
        printf "\nINSTALL_TANZU_CLUSTER_ESSENTIAL=COMPLETED\n" >> $HOME/.env
        export INSTALL_TANZU_CLUSTER_ESSENTIAL=COMPLETED
    fi
    sleep 2

    

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
    
    printf "\nCreate a registry secret...\n"
    tanzu secret registry add tap-registry --username ${INSTALL_REGISTRY_USERNAME} --password ${INSTALL_REGISTRY_PASSWORD} --server ${INSTALL_REGISTRY_HOSTNAME} --export-to-all-namespaces --yes --namespace tap-install
    printf "\n...COMPLETE\n\n"

    printf "\nCreate tanzu-tap-repository...\n"
    tanzu package repository add tanzu-tap-repository --url registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:$TAP_VERSION --namespace tap-install

    printf "\nWaiting 3m before checking...\n"
    sleep 3m
    printf "\nChecking tanzu-tap-repository status...\n"
    tanzu package repository get tanzu-tap-repository --namespace tap-install
    printf "\nDONE\n\n"

    printf "Extracting latest tap package version in 10s..."
    sleep 10s
    TAP_PACKAGE_VERSION=$(tanzu package available list tap.tanzu.vmware.com --namespace tap-install -o json | jq -r '[ .[] | {version: .version, released: .["released-at"]|split(" ")[0]} ] | sort_by(.released) | reverse[0] | .version')
    printf "$TAP_PACKAGE_VERSION"

    sed -i '/TAP_PACKAGE_VERSION/d' /root/.env
    printf "\nTAP_PACKAGE_VERSION=$TAP_PACKAGE_VERSION" >> /root/.env
    sleep 1
    sed -i '/INSTALL_TAP_PACKAGE_REPOSITORY/d' /root/.env
    printf "\nINSTALL_TAP_PACKAGE_REPOSITORY=COMPLETED\n" >> $HOME/.env

    printf "\nListing available packages in 20s...\n"
    sleep 20s
    tanzu package available list --namespace tap-install
    printf "\nDONE\n\n"
}

unset performinstall
if [[ -n $INSTALL_TAP_PACKAGE_REPOSITORY && $INSTALL_TAP_PACKAGE_REPOSITORY == 'COMPLETED' ]]
then
    printf "\nFound package repository installation is marked as complete\n"
    while true; do
        read -p "Do you want to trigger deployment again? [y/n]: " yn
        case $yn in
            [Yy]* ) performinstall="y"; printf "you confirmed yes\n"; break;;
            [Nn]* ) performinstall="n";printf "You said no.\n"; break;;
            * ) echo "Please answer y or n.";;
        esac
    done
else
    performinstall='y'
fi
if [[ $performinstall == 'y' ]]
then
    installPackageRepository
    printf "\n\n********TAP packages repository add....COMPLETE**********\n\n\n"
fi


confirmed='n'
while true; do
    read -p "Would you like to deploy TAP profile now? [y/n]: " yn
    case $yn in
        [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
        [Nn]* ) printf "You said no.\n\nExiting...\n\n"; break;;
        * ) echo "Please answer y or n.\n";;
    esac
done

if [[ $confirmed == 'y' ]]
then
    source $HOME/binaries/wizards/installprofile.sh
fi