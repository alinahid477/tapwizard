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


installTap()
{
    export $(cat /root/.env | xargs)

    printf "\n\n\n********* Checking pre-requisites *************\n\n\n"
    sleep 1
    printf "\nChecking Access to Tanzu Net...\n"
    if [[ -z $INSTALL_REGISTRY_USERNAME || -z $INSTALL_REGISTRY_PASSWORD ]]
    then
        printf "\nERROR: Tanzu Net username or password missing.\n"
        returnOrexit && return 1
    fi
    sleep 1
    printf "Access to Tanzu Net check --- COMPLETED.\n\n"
    # printf "\nChecking Cluster Specific Registry...\n"
    # if [[ -z $PVT_REGISTRY || -z $PVT_REGISTRY_USERNAME || -z $PVT_REGISTRY_PASSWORD ]]
    # then
    #     printf "\nERROR: Access information to container registry is missing.\n"
    # fi
    
    printf "\nChecking Tanzu cluster essential binary...\n"
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
            returnOrexit && return 1
        else
            numberoftarfound=$(find ~/binaries/tanzu-cluster-essentials-linux-amd64* -type f -printf "." | wc -c)
            if [[ $numberoftarfound -gt 1 ]]
            then
                printf "\nERROR: More than 1 tanzu-cluster-essentials-linux-amd64-x.x.x.tgz found in the binaries directory.\nOnly 1 is allowed.\n"
                returnOrexit && return 1
            fi
        fi
    fi
    printf "\nTanzu cluster essential binary check --- COMPLETED.\n\n"
    sleep 2

    printf "\nChecking Tanzu CLI...\n"
    sleep 1
    isinflatedTZ='n'
    DIR="$HOME/.config/tanzu"
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
            returnOrexit && return 1
        else
            numberoftarfound=$(find ~/binaries/tanzu-framework-linux-amd64* -type f -printf "." | wc -c)
            if [[ $numberoftarfound -gt 1 ]]
            then
                printf "\nERROR: More than 1 tanzu-framework-linux-amd64.tar found in the binaries directory.\nOnly 1 is allowed.\n"
                returnOrexit && return 1
            fi
        fi
    fi
    printf "\nTanzu CLI Check --- COMPLETED\n\n"
    sleep 2

    if [[ $isinflatedCE == 'n' && -n $clusteressentialsbinary ]]
    then
        printf "\nInflating Tanzu cluster essential...\n"
        sleep 1
        DIR="$HOME/tanzu-cluster-essentials"
        if [ ! -d "$DIR" ]
        then
            printf "\nCreating new $DIR...\n"
            mkdir $HOME/tanzu-cluster-essentials || returnOrexit
            if [[ $isreturnorexit == 'return' ]]
            then
                printf "\nNot proceed further...\n"
                return 1
            fi
        else
            printf "\n$DIR exits...\n"
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
            returnOrexit && return 1;
        fi
        printf "\nExtracting $clusteressentialsbinary in $DIR\n"
        tar -xvf ${clusteressentialsbinary} -C $HOME/tanzu-cluster-essentials/ || returnOrexit
        if [[ $isreturnorexit == 'return' ]]
        then
            printf "\nNot proceed further...\n"
            return 1
        fi
        printf "\nDONE\n\n"

        printf "\nInstalling cluster essential in k8s cluster...\n"
        sleep 1
        cd $HOME/tanzu-cluster-essentials
        source ./install.sh
        cp $HOME/tanzu-cluster-essentials/kapp /usr/local/bin/kapp || returnOrexit
        chmod +x /usr/local/bin/kapp || returnOrexit
        if [[ $isreturnorexit == 'return' ]]
        then
            printf "\nNot proceed further...\n"
            return 1
        fi
        kapp version
        printf "\nDONE\n\n"
        sleep 2
    fi
    if [[ $isinflatedTZ == 'n' && -n $tanzuclibinary ]]
    then
        printf "\nInflating Tanzu CLI...\n"
        sleep 1
        DIR="$HOME/tanzu"
        if [ ! -d "$DIR" ]
        then
            printf "\nCreating new $DIR...\n"
            mkdir $HOME/tanzu || returnOrexit
            if [[ $isreturnorexit == 'return' ]]
            then
                printf "\nNot proceed further...\n"
                return 1
            fi
        else
            printf "\n$DIR exits...\n"
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
            returnOrexit && return 1;
        fi
        printf "\nExtracting $tanzuclibinary in $DIR\n"
        tar -xvf $tanzuclibinary -C $HOME/tanzu/ || returnOrexit
        if [[ $isreturnorexit == 'return' ]]
        then
            printf "\nNot proceed further...\n"
            return 1
        fi
        printf "\nDONE\n\n"

        printf "\nClean install tanzu cli...\n"
        sleep 1
        cd $HOME/tanzu || returnOrexit
        install cli/core/v0.10.0/tanzu-core-linux_amd64 /usr/local/bin/tanzu || returnOrexit
        chmod +x /usr/local/bin/tanzu || returnOrexit
        tanzu version || returnOrexit

        tanzu plugin install --local cli all || returnOrexit

        tanzu plugin list
        printf "\nDONE\n\n"
        sleep 2
    fi

    while true; do
        read -p "Confirm to proceed further? [y/n]: " yn
        case $yn in
            [Yy]* ) printf "\nyou confirmed yes\n"; break;;
            [Nn]* ) printf "\n\nYou said no. \n\nExiting...\n\n"; returnOrexit && return 1;;
            * ) echo "Please answer y or n.";;
        esac
    done

    if [[ $isreturnorexit == 'return' ]]
    then
        printf "\nNot proceed further...\n"
        return 1
    fi

    printf "\nCreate namespace tap-install in k8s...\n"
    kubectl create ns tap-install
    printf "\nDONE\n\n"

    printf "\nCreate a registry secret...\n"
    tanzu secret registry add tap-registry --username ${INSTALL_REGISTRY_USERNAME} --password ${INSTALL_REGISTRY_PASSWORD} --server ${INSTALL_REGISTRY_HOSTNAME} --export-to-all-namespaces --yes --namespace tap-install
    printf "\nDONE\n\n"

    printf "\nCreate tanzu-tap-repository...\n"
    tanzu package repository add tanzu-tap-repository --url registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:1.0.0 --namespace tap-install

    printf "\nWaiting 3m before checking...\n"
    sleep 3m
    printf "\nChecking tanzu-tap-repository status...\n"
    tanzu package repository get tanzu-tap-repository --namespace tap-install
    printf "\nDONE\n\n"

    printf "\nListing available packages...\n"
    tanzu package available list --namespace tap-install
    printf "\nDONE\n\n"
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
                [Yy]* ) printf "\nyou confirmed yes\n"; confirmed='y' break;;
                [Nn]* ) printf "\n\nYou said no. \n\nExiting...\n\n"; break;;
                * ) echo "Please answer yes or no.";
            esac
        done

        if [[ $confirmed == 'n' ]]
        then
            returnOrexit && return 1
        fi


        printf "\ninstalling tap.tanzu.vmware.com in namespace tap-install...\n"
        printf "DEBUG: tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_PACKAGE_VERSION --values-file $profilefilename -n tap-install"
        # tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_PACKAGE_VERSION --values-file $profilefilename -n tap-install

        printf "\nwait 1m...\n"
        sleep 1m

        printf "\nCheck installation status....\n"
        printf "DEBUG: tanzu package installed get tap -n tap-install"
        tanzu package installed get tap -n tap-install

        printf "\nVerify that necessary packages are installed....\n"
        printf "DEBUG: tanzu package installed list -A"
        tanzu package installed list -A
        
    fi
}

# installTap
installProfile