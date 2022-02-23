#!/bin/bash
export $(cat /root/.env | xargs)

isreturnorexit='n'
returnOrexit()
{
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
    then
        isreturnorexit='return'
        return 1
    else
        isreturnorexit='exit'
        exit 1
    fi
}

installClusterEssentialTarFile () {
    printf "\nChecking Tanzu cluster essential binary..."
    sleep 1
    isinflatedCE='n'
    DIR="$HOME/tanzu-cluster-essentials"
    if [ -d "$DIR" ]
    then
        if [ "$(ls -A $DIR)" ]; then
            isinflatedCE='y'
            printf "\nFound cluster essential is already inflated in $DIR.\nSkipping further checks.\n"
        fi
    fi
    sleep 1
    if [[ $isinflatedCE == 'n' ]]
    then
        clusteressentialsbinary=$(ls ~/binaries/tanzu-cluster-essentials-linux-amd64*)
        if [[ -z $clusteressentialsbinary ]]
        then
            printf "\nERROR: tanzu-cluster-essentials-linux-amd64-x.x.x.tgz is a required binary for TAP installation.\nYou must place this binary under binaries directory.\n"
            returnOrexit || return 1
        else
            numberoftarfound=$(find ~/binaries/tanzu-cluster-essentials-linux-amd64* -type f -printf "." | wc -c)
            if [[ $numberoftarfound -gt 1 ]]
            then
                printf "\nERROR: More than 1 tanzu-cluster-essentials-linux-amd64-x.x.x.tgz found in the binaries directory.\nOnly 1 is allowed.\n"
                returnOrexit || return 1
            fi
        fi
    fi
    printf "COMPLETED.\n\n"
    sleep 2



    DIR="$HOME/tanzu-cluster-essentials"

    if [[ $isinflatedCE == 'n' && -n $clusteressentialsbinary ]]
    then
        printf "\nInflating Tanzu cluster essential...\n"
        sleep 1
        
        if [ ! -d "$DIR" ]
        then
            printf "Creating new dir:$DIR..."
            mkdir $HOME/tanzu-cluster-essentials && printf "OK" || printf "FAILED"
            printf "\n"
        else
            printf "\n$DIR already exits...\n"
            while true; do
                read -p "Confirm to untar in $DIR [y/n]: " yn
                case $yn in
                    [Yy]* ) doinflate="y"; printf "\nyou confirmed yes\n"; break;;
                    [Nn]* ) doinflate="n";printf "\n\nYou said no.\n"; break;;
                    * ) echo "Please answer y or n.";;
                esac
            done
        fi
        if [[ $doinflate == 'n' ]]
        then
            returnOrexit || return 1;
        fi
        if [ ! -d "$DIR" ]
        then
            returnOrexit || return 1
        fi
        printf "\nExtracting $clusteressentialsbinary in $DIR\n"
        tar -xvf ${clusteressentialsbinary} -C $HOME/tanzu-cluster-essentials/ || returnOrexit
        if [[ $isreturnorexit == 'return' ]]
        then
            printf "\nNot proceed further...\n"
            return 1
        fi
        printf "$clusteressentialsbinary extract in in $DIR....COMPLETED\n\n"
    fi
    
    isexist=$(kapp version)
    if [[ -d $DIR && -z $isexist ]]
    then
        printf "\nLinking kapp.....\n"
        cp $HOME/tanzu-cluster-essentials/kapp /usr/local/bin/kapp || returnOrexit
        if [[ $isreturnorexit == 'return' ]]
        then
            printf "\nNot proceed further...\n"
            return 1
        fi
        chmod +x /usr/local/bin/kapp || returnOrexit
        if [[ $isreturnorexit == 'return' ]]
        then
            printf "\nNot proceed further...\n"
            return 1
        fi
        printf "checking kapp....\n"
        kapp version
    else
        printf "\nWARN: Kapp could not be installed. Most likely $DIR missing.\n"
    fi 

}