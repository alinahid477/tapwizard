#!/bin/bash

source $HOME/binaries/scripts/returnOrexit.sh
source $HOME/binaries/scripts/color-file.sh


source $HOME/binaries/wizards/installtappackagerepository.sh
source $HOME/binaries/wizards/installtapprofile.sh
source $HOME/binaries/wizards/installdevnamespace.sh 
source $HOME/binaries/wizards/installapptoolkit.sh 

function helpFunction()
{
    printf "\n"
    echo "Usage:"
    echo -e "\t-r | --install-tap-package-repository no paramater needed. Signals the wizard to start the process for installing package repository for TAP."
    echo -e "\t-p | --install-tap-profile Signals the wizard to launch the UI for user input to take necessary inputs and deploy TAP based on profile curated from user input. Optionally pass profile file using -f or --file flag."
    echo -e "\t-n | --create-developer-namespace signals the wizard create developer namespace."
    echo -e "\t-a | --install-app-toolkit no paramater needed. Signals the wizard to start the process for installing App Toolkit package for TCE."
    echo -e "\t-h | --help"
    printf "\n"
}

unset tapPackageRepositoryInstall
unset tapProfileInstall
unset tapDeveloperNamespaceCreate
unset tceAppToolkitInstall
unset profileFile

output=""

# read the options
TEMP=`getopt -o rpnaf:h --long install-tap-package-repository,install-tap-profile,create-developer-namespace,install-app-toolkit,file:,help -n $0 -- "$@"`
eval set -- "$TEMP"
# echo $TEMP;
while true ; do
    # echo "here -- $1"
    case "$1" in
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
        -n | --create-developer-namespace )
            case "$2" in
                "" ) tapDeveloperNamespaceCreate='y'; shift 2 ;;
                * ) tapDeveloperNamespaceCreate='y' ; shift 1 ;;
            esac ;;
        -a | --install-app-toolkit )
            case "$2" in
                "" ) tceAppToolkitInstall='y'; shift 2 ;;
                * ) tceAppToolkitInstall='y' ; shift 1 ;;
            esac ;;
        -f | --file )
            case "$2" in
                "" ) profileFile=''; shift 2 ;;
                * ) profileFile=$2;  shift 2 ;;
            esac ;;
        -h | --help ) helpFunction; break;; 
        -- ) shift; break;; 
        * ) break;;
    esac
done

if [[ $tapPackageRepositoryInstall == 'y' ]]
then
    unset tapPackageRepositoryInstall
    installTapPackageRepository    
fi

if [[ $tapProfileInstall == 'y' ]]
then
    unset tapProfileInstall
    if [[ -z $profileFile ]]
    then
        installTapProfile
    else
        installTapProfile $profileFile
    fi
    unset profileFile
fi

if [[ $tapDeveloperNamespaceCreate == 'y' ]]
then
    unset tapDeveloperNamespaceCreate
    createDevNS
fi

if [[ $tceAppToolkitInstall == 'y' ]]
then
    unset tceAppToolkitInstall
    installAppToolkit
fi