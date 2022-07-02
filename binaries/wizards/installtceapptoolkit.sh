#!/bin/bash

export $(cat $HOME/.env | xargs)

source $HOME/binaries/tapscripts/extract-and-take-input.sh

installTCEAppToolkit() 
{

    local valuesFile=$1

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

    local isAppToolkitfound=''
    while [[ -z $isAppToolkitfound ]]; do
        printf "\nExtracting app-toolkit package info from available list...."
        local appToolkitVersion=$(tanzu package available list -o json | jq -rc '.[] | select(.name | contains("app-toolkit")) | ."latest-version"')
        if [[ -z $appToolkitVersion ]]
        then
            isAppToolkitfound='n'
            printf "NOT FOUND."
            printf "\n${redcolor}Error: app-toolkit does not exist or failed to extract information.${normalcolor}\n"
            printf "\nChecking for tce-repo in namespace: tanzu-package-repo-global...."
            local istcerepo=$(tanzu package repository get tce-repo --namespace tanzu-package-repo-global -o json | jq -rc '.[0] | .tag')
            if [[ -z $istcerepo ]]
            then
                printf "${redcolor}NOT FOUND.${normalcolor}\n"
                local isInstallTCERepo=''
                while true; do
                    read -p "Would you like to install tce-repo now? [y/n] " yn
                    case $yn in
                        [Yy]* ) printf "you confirmed yes\n"; isInstallTCERepo='y'; break;;
                        [Nn]* ) printf "You confirmed no.\n"; isInstallTCERepo='n'; break;;
                        * ) echo "Please answer y or n.";
                    esac
                done

                if [[ $isInstallTCERepo == 'y' ]]
                then
                    while [[ -z $TCE_REPO_URL ]]; do
                        read -p "env var TCE_REPO_URL is not set. Please provide tce-repo url: " TCE_REPO_URL
                        if [[ -z $TCE_REPO_URL  ]]
                        then
                            printf "WARN: empty value not allowed.\nType: 'none' to NOT provide any value in which case this installer will not continue.\n"
                        fi
                        if [[ $TCE_REPO_URL == 'none' ]]
                        then
                            TCE_REPO_URL=''
                            break;;
                        fi
                    done
                    if [[ -n $TCE_REPO_URL ]]
                    then
                        printf "\nInstalling tce-repo in namespace: tanzu-package-repo-global..."
                        tanzu package repository add tce-repo --url $TCE_REPO_URL --namespace tanzu-package-repo-global
                        printf "COMPLETED.\n"
                        isAppToolkitfound=''
                    fi
                fi
            else
                printf "\n${redcolor}FOUND. Error: tce-repo exists but previous attempt on get app-toolkit package did not work.${normalcolor}\n"
            fi
        else
            printf "FOUND...version: $appToolkitVersion"
            isAppToolkitfound='y'
        fi
    done
    if [[ $isAppToolkitfound == 'n' ]]
    then
        printf "\n${redcolor}Error: app-toolkit does not exist or failed to extract information. Installation will not continue..${normalcolor}\n"
        returnOrexit || return 1
    fi


    if [[ -z $valuesFile || ! -f $valuesFile ]]
    then
        local templateFilesDIR=$(echo "$HOME/binaries/templates" | xargs)
        cp $templateFilesDIR/app-toolkit-values.template /tmp/app-toolkit-values.yaml
        local appToolkitValuesFile=$(echo "/tmp/app-toolkit-values.yaml" | xargs)
        extractVariableAndTakeInput $appToolkitValuesFile

        # exclude packages that are already installed 
        local excluded_packages_STR=''
        local exclErr=''
        local exclFilename="excluded_packages-full.template"
        local exclReplace='<EXCLUDED-PACKAGES-LIST>'
        

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
        if [[ -n $excluded_packages_STR ]]
        then
            printf "\nWritting excluded packages list in app-toolkit-values file...."
            cp $templateFilesDIR/$exclFilename /tmp/
            sleep 1
            awk -v old="${exclReplace}" -v new="${excluded_packages_STR}" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' /tmp/$exclFilename > /tmp/$exclFilename.tmp || exclErr='failed'
            # sed -i 's|'$replace'|'$excluded_packages_STR'|' /tmp/$filename
            sleep 1
            if [[ -n $exclErr ]]
            then
                printf "FAILED.\n"
                returnOrexit || return 1
            fi
            cat /tmp/$exclFilename.tmp >> $appToolkitValuesFile || exclErr="failed"
            sleep 1
            if [[ -n $exclErr ]]
            then
                printf "FAILED.\n"
                returnOrexit || return 1
            fi
            printf "\n\n" >> $appToolkitValuesFile
            sleep 1
            printf "COMPLETED.\n"
            sleep 2
        else
            printf "\nWritting excluded packages list in app-toolkit-values file....NOTHING TO WRITE...Skipping...\n"
            sleep 2
        fi


        local appToolkitValuesFileName=''
        while [[ -z $appToolkitValuesFileName ]]; do
            read -p "Provide a name for this values file: " appToolkitValuesFileName
            if [[ -z $appToolkitValuesFileName || ! $appToolkitValuesFileName =~ ^[A-Za-z0-9_\-]+$ ]]
            then
                printf "WARN: empty or invalid value not allowed. A valid value comprises of numbers, letters, hyphen (-) and underscroe (_).\n"
            fi
        done
        sleep 1
        appToolkitValuesFileName=$(echo "$HOME/tapconfigs/$appToolkitValuesFileName-values.yaml")
        mv $appToolkitValuesFile $appToolkitValuesFileName
        appToolkitValuesFile=$(echo $appToolkitValuesFileName | xargs)

        printf "\nApp toolkit values file saved in: $appToolkitValuesFile\n"
    else
        appToolkitValuesFile=$(echo $valuesFile | xargs)
        printf "\nValues file provided: $appToolkitValuesFile\n"
    fi
    

    local confirmed=''
    while true; do
        read -p "Please check the the file (you may modify too) and confirm to install? [y/n] " yn
        case $yn in
            [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
            [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
            * ) echo "Please answer y or n.";
        esac
    done

    if [[ $confirmed == 'n' ]]
    then
        printf "\nThe wizard will not install app-toolkit.\n"
        returnOrexit || return 1
    fi

    local dactedpass=$(echo ${PVT_REGISTRY_PASSWORD//[a-zA-Z\/0-9]/x})
    printf "\nCreating secret called registry-credentials using\n\t--server $PVT_REGISTRY_SERVER\n\t--username $PVT_REGISTRY_USERNAME\n\t--password $dactedpass...\n"
    tanzu secret registry add registry-credentials --server $PVT_REGISTRY_SERVER --username $PVT_REGISTRY_USERNAME --password $PVT_REGISTRY_PASSWORD --export-to-all-namespaces
    sleep 2
    printf "secret called registry-credentials...CREATED\n"

    printf "\nInstalling app-toolkit in namespace tanzu-package-repo-global...\n"
    tanzu package install app-toolkit --package-name app-toolkit.community.tanzu.vmware.com --version $appToolkitVersion -f $appToolkitValuesFile -n tanzu-package-repo-global

    printf "\nwaiting for 4 mins before checking packages status..."
    sleep 4m
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