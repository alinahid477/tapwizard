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

source $HOME/binaries/scripts/generate-profile-file.sh

installProfile() 
{
    export notifyfile=/tmp/merlin-tap-notifyfile
    if [ -f "$notifyfile" ]; then
        rm $notifyfile
    fi
    unset profilefilename
    generateProfile
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

        if [[ -z $TAP_PACKAGE_VERSION ]]
        then
            printf "\nERROR: package version could not be retrieved.\n"
            printf "Execute below command manually:\n"
            printf "tanzu package install tap -p tap.tanzu.vmware.com -v {TAP_PACKAGE_VERSION} --values-file $profilefilename -n tap-install --poll-interval 5s --poll-timeout 15m0s\n"
            printf "${bluecolor}Where TAP_PACKAGE_VERSION is the version of the tap.tanzu.vmware.com you want to install${normalcolor}\n"
            returnOrexit && return 1
        fi
        printf "\ninstalling tap.tanzu.vmware.com in namespace tap-install...\n"
        #printf "DEBUG: tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_PACKAGE_VERSION --values-file $profilefilename -n tap-install --poll-interval 5s --poll-timeout 15m0s"
        tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_PACKAGE_VERSION --values-file $profilefilename -n tap-install --poll-interval 5s --poll-timeout 15m0s

        printf "\nwait 2m...\n"
        sleep 2m

        printf "\nCheck installation status....\n"
        # printf "DEBUG: tanzu package installed get tap -n tap-install"
        tanzu package installed get tap -n tap-install

        
        # printf "DEBUG: tanzu package installed list -A"
        count=1
        unset reconcileStatus
        unset ingressReconcileStatus
        while [[ -z $reconcileStatus && count -lt 5 ]]; do
            printf "\nVerify that TAP is installed....\n"
            reconcileStatus=$(tanzu package installed list -A -o json | jq -r '.[] | select(.name == "tap") | .status')
            if [[ $reconcileStatus == *@("failed")* ]]
            then
                reconcileStatus=''
            fi
            if [[ $reconcileStatus == *@("succeeded")* ]]
            then
                break
            fi
            printf "wait 2m before checking again ($count out of 4)...."
            ((count=$count+1))
            sleep 2m
        done

        printf "\nList packages status....\n"
        tanzu package installed list -A

        confirmed='n'
        while true; do
            read -p "Please confirm if reconcile for needed packages are successful? [y/n] " yn
            case $yn in
                [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                [Nn]* ) printf "You confirmed no.\n"; break;;
                * ) echo "Please answer yes or no.";
            esac
        done

        
        if [[ $confirmed == 'y' ]]
        then
            printf "\nExtracting ip of the load balancer...."
            lbip=$(kubectl get svc -n tanzu-system-ingress -o json | jq -r '.items[] | select(.spec.type == "LoadBalancer" and .metadata.name == "envoy") | .status.loadBalancer.ingress[0].ip')
            printf $lbip
            printf "\n"
            printf "${bluecolor}use this ip to create A record in the DNS zone or update profile with this ip if using xip.io or nip.io ${normalcolor}\n"
            printf "${bluecolor}To update run the below command: ${normalcolor}\n"
            printf "${bluecolor}tanzu package installed update tap -v $TAP_PACKAGE_VERSION --values-file $profilefilename -n tap-install${normalcolor}\n"

            INSTALL_TAP_PROFILE='COMPLETED'
            sed -i '/INSTALL_TAP_PROFILE/d' $HOME/.env
            printf "\nINSTALL_TAP_PROFILE=COMPLETED\n" >> $HOME/.env
            printf "\n\n********TAP profile deployment....COMPLETE**********\n\n\n"
        fi                  
    fi
}

installProfile

if [[ $INSTALL_TAP_PROFILE == 'COMPLETED' ]]
then
    unset confirmed
    while true; do
        read -p "Would you like to configure developer workspace now? [y/n] " yn
        case $yn in
            [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
            [Nn]* ) printf "You confirmed no.\n"; break;;
            * ) echo "Please answer yes or no.";
        esac
    done

    if [[ -n $confirmed && $confirmed == 'y' ]]
    then
        printf "\nTODO: Kick off developer workspace script\n"
    fi
fi