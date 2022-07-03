#!/bin/bash

source $HOME/binaries/scripts/returnOrexit.sh
source $HOME/binaries/scripts/color-file.sh

source $HOME/binaries/wizards/installtceapptoolkit.sh 
source $HOME/binaries/wizards/installtap.sh 

source $HOME/binaries/wizards/installtappackagerepository.sh
source $HOME/binaries/wizards/installtapprofile.sh
source $HOME/binaries/wizards/installdevnamespace.sh 


function helpFunction()
{
    printf "\n"
    echo "Usage:"
    echo -e "\t-r | --install-tap no paramater needed. Signals the wizard to start the process for installing TAP for Tanzu Enterprise."
    echo -e "\t-a | --install-app-toolkit no paramater needed. Signals the wizard to start the process for installing App Toolkit package for TCE. Optionally pass values file using -f or --file flag."
    echo -e "\t-r | --install-tap-package-repository no paramater needed. Signals the wizard to start the process for installing package repository for TAP."
    echo -e "\t-p | --install-tap-profile Signals the wizard to launch the UI for user input to take necessary inputs and deploy TAP based on profile curated from user input. Optionally pass profile file using -f or --file flag."
    echo -e "\t-n | --create-developer-namespace signals the wizard create developer namespace."
    echo -e "\t-h | --help"
    printf "\n"
}


unset tapInstall
unset tceAppToolkitInstall
unset tapPackageRepositoryInstall
unset tapProfileInstall
unset tapDeveloperNamespaceCreate
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


function executeCommand()
{
    
    doCheckK8sOnlyOnce

    sleep 3

    if [[ $tapInstall == 'y' ]]
    then
        unset tapInstall
        installTap
        returnOrexit || return 1
    fi
    
    if [[ $tceAppToolkitInstall == 'y' ]]
    then
        unset tceAppToolkitInstall
        if [[ -z $argFile ]]
        then
            installTCEAppToolkit
        else
            printf "\nDBG: Argument file: $argFile\n"
            installTCEAppToolkit $argFile
        fi
        unset argFile
        
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
        if [[ -z $argFile ]]
        then
            installTapProfile
        else
            installTapProfile $argFile
        fi
        unset argFile
        returnOrexit || return 1
    fi

    if [[ $tapDeveloperNamespaceCreate == 'y' ]]
    then
        unset tapDeveloperNamespaceCreate
        createDevNS
        returnOrexit || return 1
    fi

    printf "\nThis shouldn't have happened. Embarrasing.\n"
}



output=""

# read the options
TEMP=`getopt -o tarpnf:h --long install-tap,install-app-toolkit,install-tap-package-repository,install-tap-profile,create-developer-namespace,file:,help -n $0 -- "$@"`
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
    executeCommand
fi
unset ishelp