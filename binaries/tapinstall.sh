#!/bin/bash

isreturnorexit='n'
returnOrexit()
{
    isreturnorexit='y'
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
    then
        return
    else
        exit
    fi
}


export $(cat /root/.env | xargs)

printf "\n\n\n********* Checking pre-requisites *************\n\n\n"

printf "\nChecking Access to Tanzu Net...\n"
if [[ -z $TANZUNET_USERNAME || -z $TANZUNET_PASSWORD ]]
then
    printf "\nERROR: Tanzu Net username or password missing.\n"
    returnOrexit
fi

# printf "\nChecking Cluster Specific Registry...\n"
# if [[ -z $PVT_REGISTRY || -z $PVT_REGISTRY_USERNAME || -z $PVT_REGISTRY_PASSWORD ]]
# then
#     printf "\nERROR: Access information to container registry is missing.\n"
# fi

printf "\nChecking Tanzu cluster essential binary...\n"
isinflatedCE='n'
DIR="~/$HOME/tanzu-cluster-essentials"
if [ -d "$DIR" ]
then
	if [ "$(ls -A $DIR)" ]; then
        isinflatedCE='y'
        printf "\nFound cluster essential is already inflated in $DIR.\nSkipping further checks.\n"
	fi
fi
if [[ $isinflatedCE == 'n' ]]
then
    clusteressentialsbinary=$(ls ~/binaries/tanzu-cluster-essentials-linux-amd64*)
    if [[ -z $clusteressentialsbinary ]]
    then
        printf "\nERROR: tanzu-cluster-essentials-linux-amd64-x.x.x.tgz is a required binary for TAP installation.\nYou must place this binary under binaries directory.\n"
        returnOrexit
    else
        numberoftarfound=$(find ~/binaries/tanzu-cluster-essentials-linux-amd64* -type f -printf "." | wc -c)
        if [[ $numberoftarfound -gt 1 ]]
        then
            printf "\nERROR: More than 1 tanzu-cluster-essentials-linux-amd64-x.x.x.tgz found in the binaries directory.\nOnly 1 is allowed.\n"
            returnOrexit
        fi
    fi
fi
if [[ $isreturnorexit == 'y' ]]
then
    returnOrexit
fi
printf "\nTanzu cluster essential binary check --- COMPLETED.\n\n"


printf "\nChecking Tanzu CLI...\n"
isinflatedTZ='n'
DIR="~/$HOME/.config/tanzu"
if [ -d "$DIR" ]
then
	if [ "$(ls -A $DIR)" ]; then
        isinflatedTZ='y'
        printf "\nFound tanzu cli is already inflated in $DIR.\nSkipping further checks.\n"
	fi
fi
if [[ $isinflatedTZ == 'n' ]]
then
    tanzuclibinary=$(ls ~/binaries/tanzu-framework-linux-amd64*)
    if [[ -z $tanzuclibinary ]]
    then
        printf "\nERROR: tanzu-framework-linux-amd64.tar is a required binary for TAP installation.\nYou must place this binary under binaries directory.\n"
        returnOrexit
    else
        numberoftarfound=$(find ~/binaries/tanzu-framework-linux-amd64* -type f -printf "." | wc -c)
        if [[ $numberoftarfound -gt 1 ]]
        then
            printf "\nERROR: More than 1 tanzu-framework-linux-amd64.tar found in the binaries directory.\nOnly 1 is allowed.\n"
            returnOrexit
        fi
    fi
fi
if [[ $isreturnorexit == 'y' ]]
then
    returnOrexit
fi
printf "\nTanzu CLI Check --- COMPLETED\n\n"


if [[ $isinflatedCE == 'n' && -n $clusteressentialsbinary ]]
then
    printf "\nInflating Tanzu cluster essential...\n"
    mkdir $HOME/tanzu-cluster-essentials
    tar -xvf $HOME/binaries/$clusteressentialsbinary -C $HOME/tanzu-cluster-essentials/
    printf "\nDONE\n\n"

    printf "\nInstalling cluster essential in k8s cluster...\n"
    export INSTALL_BUNDLE=registry.tanzu.vmware.com/tanzu-cluster-essentials/cluster-essentials-bundle@sha256:82dfaf70656b54dcba0d4def85ccae1578ff27054e7533d08320244af7fb0343
    export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
    export INSTALL_REGISTRY_USERNAME=$TANZUNET_USERNAME
    export INSTALL_REGISTRY_PASSWORD=$TANZUNET_PASSWORD
    cd $HOME/tanzu-cluster-essentials
    source ./install.sh
    cp $HOME/tanzu-cluster-essentials/kapp /usr/local/bin/kapp
    chmod +x /usr/local/bin/kapp
    kapp version
    printf "\nDONE\n\n"
fi
if [[ $isinflatedTZ == 'n' && -n $tanzuclibinary ]]
then
    printf "\nInflating Tanzu CLI...\n"

    mkdir $HOME/tanzu
    tar -xvf $HOME/binaries/$tanzuclibinary -C $HOME/tanzu/
    printf "\nDONE\n\n"

    printf "\nClean install tanzu cli...\n"
    export TANZU_CLI_NO_INIT=true
    cd $HOME/tanzu
    install cli/core/v0.10.0/tanzu-core-linux_amd64 /usr/local/bin/tanzu
    chmod +x /usr/local/bin/tanzu
    tanzu version

    tanzu plugin install --local cli all

    tanzu plugin list
    printf "\nDONE\n\n"
fi

while true; do
    read -p "Confirm to proceed further? [y/n]: " yn
    case $yn in
        [Yy]* ) printf "\nyou confirmed yes\n"; break;;
        [Nn]* ) printf "\n\nYou said no. \n\nExiting...\n\n"; returnOrexit;;
        * ) echo "Please answer y or n.";;
    esac
done

if [[ $isreturnorexit == 'y' ]]
then
    returnOrexit
fi

export INSTALL_REGISTRY_USERNAME=$TANZUNET_USERNAME
export INSTALL_REGISTRY_PASSWORD=$TANZUNET_PASSWORD
export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com

printf "\nCreate namespace tap-install in k8s...\n"
kubectl create ns tap-install
printf "\nDONE\n\n"

printf "\nCreate a registry secret...\n"
tanzu secret registry add tap-registry --username ${INSTALL_REGISTRY_USERNAME} --password ${INSTALL_REGISTRY_PASSWORD} --server ${INSTALL_REGISTRY_HOSTNAME} --export-to-all-namespaces --yes --namespace tap-install
printf "\nDONE\n\n"

printf "\nCreate a registry secret...\n"
tanzu package repository add tanzu-tap-repository --url registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:1.0.0 --namespace tap-install

printf "\nWaiting 3m before checking...\n"
sleep 3m
tanzu package repository get tanzu-tap-repository --namespace tap-install
printf "\nDONE\n\n"
