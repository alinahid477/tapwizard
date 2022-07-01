#!/bin/bash

export $(cat $HOME/.env | xargs)

source $HOME/binaries/tapscripts/extract-and-take-input.sh

installTCEAppToolkit() 
{

    printf "\n\n\n********* installing app-toolkit *************\n\n\n"

    local installedPackages=$(tanzu package installed list -A -o json)

    printf "\nChecking for app-toolkit from installed list..."
    local isexist=$(echo $installedPackages | jq -rc '.[] | select(."package-name" | contains("app-toolkit.")) | ."package-version"')
    if [[ -n $isexist ]]
    then
        printf "FOUND"
        printf "\nDetails:\n"
        echo $installedPackages | jq -r '.[] | select(."package-name" | contains("app-toolkit."))'
        printf "\n${redcolor}Error: Installation will not continue as app-toolkit is already exists in cluster.${normalcolor}\n"
        returnOrexit || return 1
    else
        printf "NOT FOUND. Continuing..."
        printf "\n"
    fi


    printf "\nExtracting app-toolkit package info from available list...."
    local appToolkitVersion=$(tanzu package available list -o json | jq -rc '.[] | select(.name | contains("app-toolkit")) | ."latest-version"')
    if [[ -z $appToolkitVersion ]]
    then
        printf "NOT FOUND."
        printf "\n${redcolor}Error: app-toolkit does not exist or failed to extract information. Installation will not continue.${normalcolor}\n"    
        returnOrexit || return 1
    fi


    printf "FOUND...version: $appToolkitVersion"
    local templateFilesDIR=$(echo "$HOME/binaries/templates" | xargs)

    cp $templateFilesDIR/app-toolkit-values.template /tmp/app-toolkit-values.yaml
    local appToolkitValuesFile=$(echo "/tmp/app-toolkit-values.yaml" | xargs)
    extractVariableAndTakeInput $appToolkitValuesFile

    # exclude packages that are already installed 
    local excluded_packages_STR=''
    local exclErr=''
    local exclFilename="excluded_packages-full.template"
    local exclReplace='<EXCLUDED-PACKAGES-LIST>'
    cp $templateFilesDIR/$exclFilename /tmp/

    local packagesToCheck=(cert-manager contour fluxcd-source-controller knative-serving kpack kpack-dependencies)
    for i in "${packagesToCheck[@]}"
    do
        printf "\nChecking if $i already installed...."
        isexist=$(echo $installedPackages | jq -rc '.[] | select(."package-name" | contains("'$i'.")) | ."package-version"')
        if [[ -n $isexist ]] 
        then
            printf "INSTALLED. version: $isexist. Excluding...\n"
            if [[ -z $excluded_packages_STR ]]
            then
                excluded_packages_STR="  - $i"
            else
                excluded_packages_STR="$excluded_packages_STR\n  - $i"
            fi
        fi
    done
    awk -v old="${exclReplace}" -v new="${excluded_packages_STR}" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' /tmp/$exclFilename > /tmp/$exclFilename.tmp || exclErr='failed'
    # sed -i 's|'$replace'|'$excluded_packages_STR'|' /tmp/$filename
    if [[ -n $exclErr ]]
    then
        printf "FAILED.\n"
        returnOrexit || return 1
    fi
    cat /tmp/$exclFilename.tmp >> $appToolkitValuesFile || exclErr="failed"
    if [[ -n $exclErr ]]
    then
        printf "FAILED.\n"
        returnOrexit || return 1
    fi
    printf "\n\n" >> $appToolkitValuesFile
    printf "\n"
    printf "\nInstalling in namespace tanzu-package-repo-global...\n"

    tanzu package install app-toolkit --package-name app-toolkit.community.tanzu.vmware.com --version $appToolkitVersion -f $appToolkitValuesFile -n tanzu-package-repo-global

    printf "\nwaiting for 4 mins before checking packages status..."
    sleep 4
    tanzu package installed list -A

    local issuccess=''
    while true; do
        read -p "Are the statuses for packages 'Reconcile succeeded'? [y/n]: " yn
        case $yn in
            [Yy]* ) issuccess="y"; printf "you confirmed yes\n"; break;;
            [Nn]* ) issuccess="n";printf "You said no.\n"; break;;
            * ) echo "Please answer y or n.";;
        esac
    done
    if [[ $issuccess == 'y' ]]
    then
        printf "\nInstallation of installing app-toolkit...COMPLETED\n\n\n"
    else
        printf "\nTry running 'tanzu package installed list -A' few mins later to check reconcile status if it is still reconciling.\nIf reconciliation failed then please remove the package by running 'tanzu package installed delete app-toolkit -n tanzu-package-repo-global AND try 'merlin --install-app-toolkit' again"
    fi    
}