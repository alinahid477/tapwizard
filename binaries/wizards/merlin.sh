#!/bin/bash

source $HOME/binaries/scripts/returnOrexit.sh
source $HOME/binaries/scripts/color-file.sh

source $HOME/binaries/wizards/installtceapptoolkit.sh 
source $HOME/binaries/wizards/installtap.sh 

source $HOME/binaries/wizards/installtappackagerepository.sh
source $HOME/binaries/wizards/installtapprofile.sh
source $HOME/binaries/wizards/installdevnamespace.sh

source $HOME/binaries/wizards/configurekpack.sh
source $HOME/binaries/wizards/carto.sh

function helpFunction()
{
    printf "\n"
    echo "Usage:"
    echo -e "\t-t | --install-tap no paramater needed. Signals the wizard to start the process for installing TAP for Tanzu Enterprise."
    echo -e "\t-a | --install-app-toolkit no paramater needed. Signals the wizard to start the process for installing App Toolkit package for TCE. Optionally pass values file using -f or --file flag."
    echo -e "\t-r | --install-tap-package-repository no paramater needed. Signals the wizard to start the process for installing package repository for TAP."
    echo -e "\t-p | --install-tap-profile Signals the wizard to launch the UI for user input to take necessary inputs and deploy TAP based on profile curated from user input. Optionally pass profile file using -f or --file flag."
    echo -e "\t-n | --create-developer-namespace signals the wizard create developer namespace."
    echo -e "\t-k | --configure-kpack signals the wizard create developer namespace."
    echo -e "\t-c | --configure-carto-templates signals the wizard start creating cartographer templates for supply-chain."
    echo -e "\t-s | --create-carto-supplychain signals the wizard start creating cartographer supply-chain."
    echo -e "\t-d | --create-carto-delivery signals the wizard start creating cartographer delivery (for git-ops)."
    echo -e "\t-h | --help"
    printf "\n"
}


unset tapInstall
unset tceAppToolkitInstall
unset tapPackageRepositoryInstall
unset tapProfileInstall
unset tapDeveloperNamespaceCreate
unset wizardConfigureKpack
unset wizardConfigureCartoTemplates
unset wizardCreateCartoSupplychain
unset wizardCreateCartoDelivery
unset argFile
unset ishelp

function doCheckK8sOnlyOnce()
{
    if [[ ! -f /tmp/checkedConnectedK8s  ]]
    then
        source $HOME/binaries/scripts/init-checkk8s.sh
        echo "y" >> /tmp/checkedConnectedK8s
    fi
}


function executeCommand () {
    
    doCheckK8sOnlyOnce

    local file=$1

    if [[ $tapInstall == 'y' ]]
    then
        unset tapInstall
        installTap
        returnOrexit || return 1
    fi
    
    if [[ $tceAppToolkitInstall == 'y' ]]
    then
        unset tceAppToolkitInstall
        if [[ -z $file ]]
        then
            installTCEAppToolkit
        else
            printf "\nDBG: Argument file: $file\n"
            installTCEAppToolkit $file
        fi        
        returnOrexit || return 1
    fi

    if [[ $tapPackageRepositoryInstall == 'y' ]]
    then
        unset tapPackageRepositoryInstall
        installTapPackageRepository    
        returnOrexit || return 1
    fi

    if [[ $tapProfileInstall == 'y' ]]
    then
        unset tapProfileInstall
        if [[ -z $file ]]
        then
            installTapProfile
        else
            installTapProfile $file
        fi
        returnOrexit || return 1
    fi

    if [[ $tapDeveloperNamespaceCreate == 'y' ]]
    then
        unset tapDeveloperNamespaceCreate
        createDevNS
        returnOrexit || return 1
    fi

    if [[ $wizardConfigureKpack == 'y' ]]
    then
        unset wizardConfigureKpack
        startConfigureKpack
        returnOrexit || return 1
    fi

    if [[ $wizardConfigureCartoTemplates == 'y' ]]
    then
        unset wizardConfigureCartoTemplates
        createCartoTemplates
        returnOrexit || return 1
    fi

    if [[ $wizardCreateCartoSupplychain == 'y' ]]
    then
        unset wizardCreateCartoSupplychain
        createSupplyChain
        returnOrexit || return 1
    fi

    if [[ $wizardCreateCartoDelivery == 'y' ]]
    then
        unset wizardCreateCartoDelivery
        createDeliveryBasic
        returnOrexit || return 1
    fi

    printf "\nThis shouldn't have happened. Embarrasing.\n"
}



output=""

# read the options
TEMP=`getopt -o tarpnkf:csdh --long install-tap,install-app-toolkit,install-tap-package-repository,install-tap-profile,create-developer-namespace,configure-kpack,file:,configure-carto-templates,create-carto-supplychain,create-carto-delivery,help -n $0 -- "$@"`
eval set -- "$TEMP"
# echo $TEMP;
while true ; do
    # echo "here -- $1"
    case "$1" in
        -t | --install-tap )
            case "$2" in
                "" ) tapInstall='y';  shift 2 ;;
                * ) tapInstall='y' ;  shift 1 ;;
            esac ;;
        -a | --install-app-toolkit )
            case "$2" in
                "" ) tceAppToolkitInstall='y'; shift 2 ;;
                * ) tceAppToolkitInstall='y' ; shift 1 ;;
            esac ;;
        -n | --create-developer-namespace )
            case "$2" in
                "" ) tapDeveloperNamespaceCreate='y'; shift 2 ;;
                * ) tapDeveloperNamespaceCreate='y' ; shift 1 ;;
            esac ;;
        -r | --install-tap-package-repository )
            case "$2" in
                "" ) tapPackageRepositoryInstall='y';  shift 2 ;;
                * ) tapPackageRepositoryInstall='y' ;  shift 1 ;;
            esac ;;
        -p | --install-tap-profile )
            case "$2" in
                "" ) tapProfileInstall='y'; shift 2 ;;
                * ) tapProfileInstall='y' ; shift 1 ;;
            esac ;;
        -k | --configure-kpack )
            case "$2" in
                "" ) wizardConfigureKpack='y'; shift 2 ;;
                * ) wizardConfigureKpack='y' ; shift 1 ;;
            esac ;;
        -c | --configure-carto-templates )
            case "$2" in
                "" ) wizardConfigureCartoTemplates='y'; shift 2 ;;
                * ) wizardConfigureCartoTemplates='y' ; shift 1 ;;
            esac ;;
        -s | --create-carto-supplychain )
            case "$2" in
                "" ) wizardCreateCartoSupplychain='y'; shift 2 ;;
                * ) wizardCreateCartoSupplychain='y' ; shift 1 ;;
            esac ;;
        -s | --create-carto-delivery )
            case "$2" in
                "" ) wizardCreateCartoDelivery='y'; shift 2 ;;
                * ) wizardCreateCartoDelivery='y' ; shift 1 ;;
            esac ;;
        -f | --file )
            case "$2" in
                "" ) argFile=''; shift 2 ;;
                * ) argFile=$2;  shift 2 ;;
            esac ;;
        -h | --help ) ishelp='y'; helpFunction; break;; 
        -- ) shift; break;; 
        * ) break;;
    esac
done

if [[ $ishelp != 'y' ]]
then
    executeCommand $argFile
    unset argFile
fi
unset ishelp