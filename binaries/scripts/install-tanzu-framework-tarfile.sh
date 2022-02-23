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


installTanzuFrameworkTarFile () {
    printf "\nChecking Tanzu Framework binary..."
    sleep 1
    isinflatedTZ='n'
    DIR="$HOME/tanzu"
    if [ -d "$DIR" ]
    then
        if [ "$(ls -A $DIR)" ]; then
            isinflatedTZ='y'
            printf "\nFound tanzu cli is already inflated in $DIR.\nSkipping further checks.\n"
        fi
    fi
    sleep 1
    if [[ $isinflatedTZ == 'n' ]]
    then
        tanzuclibinary=$(ls ~/binaries/tanzu-framework-linux-amd64*)
        if [[ -z $tanzuclibinary ]]
        then
            printf "\nERROR: tanzu-framework-linux-amd64.tar is a required binary for TAP installation.\nYou must place this binary under binaries directory.\n"
            returnOrexit || return 1
        else
            numberoftarfound=$(find ~/binaries/tanzu-framework-linux-amd64* -type f -printf "." | wc -c)
            if [[ $numberoftarfound -gt 1 ]]
            then
                printf "\nERROR: More than 1 tanzu-framework-linux-amd64.tar found in the binaries directory.\nOnly 1 is allowed.\n"
                returnOrexit || return 1
            fi
        fi
    fi
    printf "COMPLETED\n\n"
    sleep 2

    DIR="$HOME/tanzu"
    if [[ $isinflatedTZ == 'n' && -n $tanzuclibinary ]]
    then
        printf "\nInflating Tanzu CLI...\n"
        sleep 1
        if [ ! -d "$DIR" ]
        then
            printf "Creating new $DIR..."
            mkdir $HOME/tanzu && printf "OK" || printf "FAILED"
            printf "\n"
        else
            printf "$DIR already exits...\n"
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
            printf "\nNot proceed further...\n"
            returnOrexit || return 1
        fi
        printf "\nExtracting $tanzuclibinary in $DIR....\n"
        tar -xvf $tanzuclibinary -C $HOME/tanzu/ || returnOrexit
        if [[ $isreturnorexit == 'return' ]]
        then
            printf "\nNot proceed further...\n"
            return 1
        fi
        printf "\n$tanzuclibinary extract in $DIR......COMPLETED.\n\n"
    fi

    
    isexist=$(tanzu version)
    if [[ -d $DIR && -z $isexist ]]
    then
        printf "\nLinking tanzu cli...\n"
        tanzuframworkVersion=$(ls $HOME/tanzu/cli/core/ | grep "^v[0-9\.]*$")        
        if [[ -z $tanzuframworkVersion ]]
        then
            printf "\nERROR: could not found version dir in the tanzu/cli/core.\n"
            returnOrexit || return 1;
        fi
        cd $HOME/tanzu || returnOrexit
        install cli/core/$tanzuframworkVersion/tanzu-core-linux_amd64 /usr/local/bin/tanzu || returnOrexit
        chmod +x /usr/local/bin/tanzu || returnOrexit
        tanzu version || returnOrexit
        if [[ ! -d $HOME/.local/share/tanzu-cli ]]
        then
            printf "installing tanzu plugin from local..."
            tanzu plugin install --local cli all || returnOrexit
            printf "COMPLETE.\n"
            tanzu plugin list
            printf "\nTanzu framework installation...COMPLETE.\n\n"
        fi
        sleep 2
        printf "DONE\n\n"
    fi
}