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


installPackageRepository()
{
    export $(cat /root/.env | xargs)

    printf "\n\n\n********* Checking pre-requisites *************\n\n\n"
    sleep 1
    printf "\nChecking Access to Tanzu Net..."
    if [[ -z $INSTALL_REGISTRY_USERNAME || -z $INSTALL_REGISTRY_PASSWORD ]]
    then
        printf "\nERROR: Tanzu Net username or password missing.\n"
        returnOrexit && return 1
    fi
    sleep 1
    printf "COMPLETED.\n\n"
    # printf "\nChecking Cluster Specific Registry...\n"
    # if [[ -z $PVT_REGISTRY || -z $PVT_REGISTRY_USERNAME || -z $PVT_REGISTRY_PASSWORD ]]
    # then
    #     printf "\nERROR: Access information to container registry is missing.\n"
    # fi
    
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
    printf "COMPLETED.\n\n"
    sleep 2

    printf "\nChecking Tanzu Framework binary..."
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
    printf "COMPLETED\n\n"
    sleep 2

    if [[ $isinflatedCE == 'n' && -n $clusteressentialsbinary ]]
    then
        printf "\nInflating Tanzu cluster essential...\n"
        sleep 1
        DIR="$HOME/tanzu-cluster-essentials"
        if [ ! -d "$DIR" ]
        then
            printf "Creating new dir:$DIR...\n"
            mkdir $HOME/tanzu-cluster-essentials || returnOrexit && return 1
            if [[ $isreturnorexit == 'return' ]]
            then
                printf "\nNot proceed further...\n"
                return 1
            fi
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
            returnOrexit && return 1;
        fi
        printf "\nExtracting $clusteressentialsbinary in $DIR\n"
        tar -xvf ${clusteressentialsbinary} -C $HOME/tanzu-cluster-essentials/ || returnOrexit
        if [[ $isreturnorexit == 'return' ]]
        then
            printf "\nNot proceed further...\n"
            return 1
        fi
        printf "$clusteressentialsbinary extract in in $DIR....COMPLETED\n\n"

        unset performinstall
        if [[ -n $INSTALL_TANZU_CLUSTER_ESSENTIAL && $INSTALL_TANZU_CLUSTER_ESSENTIAL == 'COMPLETED' ]]
        then
            printf "\nFound tanzu-cluster-essential installation is marked as complete\n"
            while true; do
                read -p "Do you want to trigger deployment again? [y/n]: " yn
                case $yn in
                    [Yy]* ) performinstall="y"; printf "you confirmed yes\n"; break;;
                    [Nn]* ) performinstall="n";printf "You said no.\n"; break;;
                    * ) echo "Please answer y or n.";;
                esac
            done
        else
            performinstall='y'
        fi
        if [[ $performinstall == 'y' ]]
        then
            printf "\nInstalling cluster essential in k8s cluster...\n\n"
            sleep 1
            cd $HOME/tanzu-cluster-essentials
            source ./install.sh
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
            printf "checking kapp...."
            kapp version
            printf "\nTanzu cluster essential instllation....COMPLETED\n\n"
        fi
        if [[ -z $INSTALL_TANZU_CLUSTER_ESSENTIAL ]]
        then
            printf "\nINSTALL_TANZU_CLUSTER_ESSENTIAL=COMPLETED\n" >> $HOME/.env
        fi
        sleep 2
    fi
    if [[ $isinflatedTZ == 'n' && -n $tanzuclibinary ]]
    then
        printf "\nInflating Tanzu CLI...\n"
        sleep 1
        DIR="$HOME/tanzu"
        if [ ! -d "$DIR" ]
        then
            printf "Creating new $DIR...\n"
            mkdir $HOME/tanzu || returnOrexit
            if [[ $isreturnorexit == 'return' ]]
            then
                printf "\nNot proceed further...\n"
                return 1
            fi
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
            returnOrexit && return 1;
        fi
        printf "\nExtracting $tanzuclibinary in $DIR....\n"
        tar -xvf $tanzuclibinary -C $HOME/tanzu/ || returnOrexit
        if [[ $isreturnorexit == 'return' ]]
        then
            printf "\nNot proceed further...\n"
            return 1
        fi
        printf "\n$tanzuclibinary extract in $DIR......COMPLETED.\n\n"
        
        printf "\nClean install tanzu cli...\n"
        sleep 1

        tanzuframworkVersion=$(ls $HOME/tanzu/cli/core/ | grep "^v[0-9\.]*$")        
        if [[ -z $tanzuframworkVersion ]]
        then
            printf "\nERROR: could not found version dir in the tanzu/cli/core.\n"
            returnOrexit && return 1;
        fi
        cd $HOME/tanzu || returnOrexit
        install cli/core/$tanzuframworkVersion/tanzu-core-linux_amd64 /usr/local/bin/tanzu || returnOrexit
        chmod +x /usr/local/bin/tanzu || returnOrexit
        tanzu version || returnOrexit
        printf "installing tanzu plugin from local..."
        tanzu plugin install --local cli all || returnOrexit
        printf "COMPLETE.\n"
        tanzu plugin list
        printf "\nTanzu framework installation...COMPLETE.\n\n"
        sleep 2
    fi

    unset confirmed
    while true; do
        read -p "Confirm to proceed further? [y/n]: " yn
        case $yn in
            [Yy]* ) confirmed='y'; printf "you confirmed yes\n"; break;;
            [Nn]* ) confirmed='n'; printf "You said no.\n\nExiting...\n\n"; break;;
            * ) echo "Please answer y or n.";;
        esac
    done

    if [[ $confirmed == 'n' ]]
    then
        printf "\nNot proceed further...\n"
        returnOrexit && return 1
    fi

    isexist=$(kubectl get ns | grep "^tap-install")
    if [[ -z $isexist ]]
    then
        printf "\nCreate namespace tap-install in k8s..."
        kubectl create ns tap-install
        printf "\n....COMPLETE\n\n"
    fi
    
    printf "\nCreate a registry secret...\n"
    tanzu secret registry add tap-registry --username ${INSTALL_REGISTRY_USERNAME} --password ${INSTALL_REGISTRY_PASSWORD} --server ${INSTALL_REGISTRY_HOSTNAME} --export-to-all-namespaces --yes --namespace tap-install
    printf "\n...COMPLETE\n\n"

    printf "\nCreate tanzu-tap-repository...\n"
    tanzu package repository add tanzu-tap-repository --url registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:$TAP_VERSION --namespace tap-install

    printf "\nWaiting 3m before checking...\n"
    sleep 3m
    printf "\nChecking tanzu-tap-repository status...\n"
    tanzu package repository get tanzu-tap-repository --namespace tap-install
    printf "\nDONE\n\n"

    printf "Extracting latest tap package version in 10s..."
    sleep 10s
    TAP_PACKAGE_VERSION=$(tanzu package available list tap.tanzu.vmware.com --namespace tap-install -o json | jq -r '[ .[] | {version: .version, released: .["released-at"]|split(" ")[0]} ] | sort_by(.released) | reverse[0] | .version')
    printf "$TAP_PACKAGE_VERSION"

    sed -i '/TAP_PACKAGE_VERSION/d' /root/.env
    printf "\nTAP_PACKAGE_VERSION=$TAP_PACKAGE_VERSION" >> /root/.env
    sleep 1
    sed -i '/INSTALL_TAP_PACKAGE_REPOSITORY/d' /root/.env
    printf "\nINSTALL_TAP_PACKAGE_REPOSITORY=COMPLETED\n" >> $HOME/.env

    printf "\nListing available packages in 20s...\n"
    sleep 20s
    tanzu package available list --namespace tap-install
    printf "\nDONE\n\n"
}

unset performinstall
if [[ -n $INSTALL_TAP_PACKAGE_REPOSITORY && $INSTALL_TAP_PACKAGE_REPOSITORY == 'COMPLETED' ]]
then
    printf "\nFound package repository installation is marked as complete\n"
    while true; do
        read -p "Do you want to trigger deployment again? [y/n]: " yn
        case $yn in
            [Yy]* ) performinstall="y"; printf "you confirmed yes\n"; break;;
            [Nn]* ) performinstall="n";printf "You said no.\n"; break;;
            * ) echo "Please answer y or n.";;
        esac
    done
else
    performinstall='y'
fi
if [[ $performinstall == 'y' ]]
then
    installPackageRepository
    printf "\n\n********TAP packages repository add....COMPLETE**********\n\n\n"
fi


confirmed='n'
while true; do
    read -p "Would you like to deploy TAP profile now? [y/n]: " yn
    case $yn in
        [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
        [Nn]* ) printf "You said no.\n\nExiting...\n\n"; break;;
        * ) echo "Please answer y or n.\n";;
    esac
done

if [[ $confirmed == 'y' ]]
then
    source $HOME/binaries/installprofile.sh
fi