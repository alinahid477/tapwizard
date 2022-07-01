#!/bin/bash

export $(cat $HOME/.env | xargs)


installTap()
{
    printf "\n\n************Checking if TAP is already installed on k8s cluster**********\n"
    # This logic is flawd. Need to change to something solid
    sleep 1
    local isexist='y'
    if [[ -z $INSTALL_TAP_PROFILE || $INSTALL_TAP_PROFILE != 'COMPLETED' ]]
    then
        printf "Checking tap-install in k8s...\n"
        local istapinstalled=$(kubectl get packageinstalls.packaging.carvel.dev -n tap-install | grep -w tap)
        if [[ -n $istapinstalled ]]
        then
            printf "Found tap in tap-install ns in the k8s but .env is not marked as complete. Marking as complete...."
            sed -i '/INSTALL_TAP_PROFILE/d' /root/.env
            printf "\nINSTALL_TAP_PROFILE=COMPLETED" >> /root/.env
            export INSTALL_TAP_PROFILE=COMPLETED
            printf "DONE.\n"
        else
            printf "TAP is not found in the k8s cluster (ns: tap-install is missing or empty).\n\n"
            if [[ -z $COMPLETE || $COMPLETE == 'NO' ]]
            then
                isexist="n"    
            fi
        fi
    fi   

    if [[ -n $INSTALL_TAP_PROFILE && $INSTALL_TAP_PROFILE == 'COMPLETED' ]]
    then
        printf "\n\nINSTALL_TAP_PROFILE is marked as $INSTALL_TAP_PROFILE.\n"
        if [[ -z $COMPLETE || $COMPLETE == 'NO' ]]
        then
            # printf "Checking tap package version..."
            # istapversion=$(tanzu package available list tap.tanzu.vmware.com --namespace tap-install -o json | jq -r '[ .[] | {version: .version, released: .["released-at"]|split(" ")[0]} ] | sort_by(.released) | reverse[0] | .version')
            printf "\n\n.env is not marked as overall completed. Marking as complete...."
            sed -i '/COMPLETE/d' /root/.env
            printf "\nCOMPLETE=YES" >> /root/.env
            export COMPLETE=YES
            printf "DONE.\n\n"
        fi
    fi
    printf "\n\n----------Finished Checking---------\n\n\n"
    sleep 2

    if [[ $isexist == 'y' || $COMPLETE == 'YES' ]]
    then
        printf "${yellowcolor}This installer has detected that TAP is marked as COMPLETED in the .env.${normalcolor}\n"
        printf "Performing tanzu package installed get tap -n tap-install...\n"
        tanzu package installed get tap -n tap-install
        printf "\n\n"
        while true; do
            read -p "Would you like to re-deploy tap? [y/n]: " yn
            case $yn in
                [Yy]* ) isexist='n'; printf "you confirmed yes.\n"; break;;
                [Nn]* ) isexist='y'; printf "You said no.\n"; break;;
                * ) echo "Please answer y or n.";;
            esac
        done
    fi

    local doinstall=''

    if [[ $isexist == "n" && $INSTALL_TAP_PACKAGE_REPOSITORY != 'COMPLETED' ]]
    then
        while true; do
            read -p "Confirm if you like to deploy Tanzu Application Platform (TAP) on this k8s cluster now [y/n]: " yn
            case $yn in
                [Yy]* ) doinstall="y"; printf "\nyou confirmed yes\n"; break;;
                [Nn]* ) printf "\n\nYou said no.\n"; break;;
                * ) echo "Please answer y or n.";;
            esac
        done
    fi

    if [[ $INSTALL_TAP_PACKAGE_REPOSITORY == 'COMPLETED' ]]
    then
        doinstall="y"
    fi

    if [[ $doinstall == "y" ]] 
    then
        local performinstall=''
        if [[ $INSTALL_TAP_PACKAGE_REPOSITORY == 'COMPLETED' ]]
        then
            printf "\nFound package repository installation is marked as complete\n"
            while true; do
                read -p "Do you want to trigger install tap-package-repository again? [y/n]: " yn
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
            source $HOME/binaries/wizards/installtappackagerepository.sh
            installTapPackageRepository
            printf "\n\n********TAP packages repository add....COMPLETE**********\n\n\n"
        fi
        sleep 3

        performinstall='n'
        if [[ $INSTALL_TAP_PACKAGE_REPOSITORY == 'COMPLETED' ]]
        then
            while true; do
                if [[ $INSTALL_TAP_PROFILE == 'COMPLETED' ]]
                then
                    read -p "Would you like to re-deploy TAP profile now? [y/n]: " yn
                else
                    read -p "Would you like to deploy TAP profile now? [y/n]: " yn
                fi
                
                case $yn in
                    [Yy]* ) printf "you confirmed yes\n"; performinstall='y'; break;;
                    [Nn]* ) printf "You said no.\n\nExiting...\n\n"; break;;
                    * ) echo "Please answer y or n.\n";;
                esac
            done
        fi
        
        if [[ $performinstall == 'y' ]]
        then
            source $HOME/binaries/wizards/installtapprofile.sh
            installTapProfile
        fi
        sleep 3

        performinstall='n'
        if [[ $INSTALL_TAP_PROFILE == 'COMPLETED' ]]
        then            
            while true; do
                read -p "Would you like to configure developer workspace now? [y/n] " yn
                case $yn in
                    [Yy]* ) printf "you confirmed yes\n"; performinstall='y'; break;;
                    [Nn]* ) printf "You confirmed no.\n"; break;;
                    * ) echo "Please answer yes or no.";
                esac
            done

            if [[ $performinstall == 'y' ]]
            then
                source $HOME/binaries/wizards/installdevnamespace.sh
                createDevNS
            fi
        fi

    fi    
 

    

}