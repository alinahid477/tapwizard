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

installProfile() 
{
    export notifyfile=/tmp/merlin-tap-notifyfile
    if [ -f "$notifyfile" ]; then
        rm $notifyfile
    fi
    unset profilefilename
    source $HOME/binaries/generate-profile-file.sh
    if [ -f "$notifyfile" ]; then
        profilefilename=$(cat $notifyfile)
    fi
    if [[ -n $profilefilename && -f $profilefilename && $SILENTMODE != 'y' ]]
    then
        confirmed='n'
        while true; do
            read -p "Review the file and confirm to continue? [y/n] " yn
            case $yn in
                [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                [Nn]* ) printf "You confirmed no.\n"; break;;
                * ) echo "Please answer yes or no.";
            esac
        done

        if [[ $confirmed == 'n' ]]
        then
            returnOrexit && return 1
        fi


        printf "\ninstalling tap.tanzu.vmware.com in namespace tap-install...\n"
        printf "DEBUG: tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_PACKAGE_VERSION --values-file $profilefilename -n tap-install --poll-interval 5s --poll-timeout 15m0s"
        # tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_PACKAGE_VERSION --values-file $profilefilename -n tap-install

        printf "\nwait 1m...\n"
        sleep 1m

        printf "\nCheck installation status....\n"
        printf "DEBUG: tanzu package installed get tap -n tap-install"
        # tanzu package installed get tap -n tap-install

        printf "\nVerify that necessary packages are installed....\n"
        printf "DEBUG: tanzu package installed list -A"
        # tanzu package installed list -A
        
    fi
}

installProfile