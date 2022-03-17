#!/bin/bash


function helpFunction()
{
    printf "\n"
    echo "Usage:"
    echo -e "\t-r | --install-package-repository no paramater needed. Signals the wizard to start the process for installing package repository for TAP."
    echo -e "\t-p | --install-profile Signals the wizard to launch the UI for user input to take necessary inputs and deploy TAP based on profile curated from user input. Optionally pass profile file using -f or --file flag."
    echo -e "\t-n | --create-tap-namespace signals the wizard create developer namespace."
    echo -e "\t-h | --help"
    printf "\n"
}

unset packageRepositoryInstall
unset profileInstall
unset tapNamespaceCreate
unset profileFile

output=""

# read the options
TEMP=`getopt -o rpnf:h --long install-package-repository,install-profile,create-tap-namespace,file:,help -n $0 -- "$@"`
eval set -- "$TEMP"
# echo $TEMP;
while true ; do
    # echo "here -- $1"
    case "$1" in
        -r | --install-package-repository )
            case "$2" in
                "" ) packageRepositoryInstall='y';  shift 2 ;;
                * ) packageRepositoryInstall='y' ;  shift 1 ;;
            esac ;;
        -p | --install-profile )
            case "$2" in
                "" ) profileInstall='y'; shift 2 ;;
                * ) profileInstall='y' ; shift 1 ;;
            esac ;;
        -n | --create-tap-namespace )
            case "$2" in
                "" ) tapNamespaceCreate='y'; shift 2 ;;
                * ) tapNamespaceCreate='y' ; shift 1 ;;
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

if [[ $packageRepositoryInstall == 'y' ]]
then
    source $HOME/binaries/wizards/installpackagerepository.sh
else
    if [[ $profileInstall == 'y' ]]
    then
        if [[ -z $profileFile ]]
        then
            source $HOME/binaries/wizards/installprofile.sh
        else
            source $HOME/binaries/wizards/installprofile.sh $profileFile
        fi
    else
        if [[ $tapNamespaceCreate == 'y' ]]
        then
           source $HOME/binaries/wizards/installdevnamespace.sh 
        fi
    fi
fi
