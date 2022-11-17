#!/bin/bash

export $(cat $HOME/.env | xargs)

source $HOME/binaries/scripts/returnOrexit.sh
source $HOME/binaries/tapscripts/generate-profile-file.sh

installTapProfile() 
{
    local bluecolor=$(tput setaf 4)
    local normalcolor=$(tput sgr0)
    local profilefilename=$1


    # PATCH: Dockerhub is special case
    # This patch is so that 
    #   tanzu secret registry add registry-credentials --server PVT-REGISTRY-SERVER requires dockerhub to be: https://index.docker.io/v1/
    #   BUT
    #   Apptoolkit.values files AND tap-profile values file expects: index.docker.io.
    # Hence I am using CARTO_CATALOG_PVT_REGISTRY_SERVER for the values file just in case.
    # AND doing the below if block to export (derive) the value of CARTO_CATALOG_PVT_REGISTRY_SERVER just for dockerhub.
    # CARTO_CATALOG_PVT_REGISTRY_SERVER is a fail safe.
    if [[ -n $PVT_REGISTRY_SERVER && $PVT_REGISTRY_SERVER =~ .*"index.docker.io".* ]]
    then
        export CARTO_CATALOG_PVT_REGISTRY_SERVER='index.docker.io'
    fi

    if [[ -z $profilefilename ]]
    then
        export notifyfile=/tmp/merlin-tap-notifyfile
        if [ -f "$notifyfile" ]; then
            rm $notifyfile
        fi
        
        generateProfile
        if [ -f "$notifyfile" ]; then
            profilefilename=$(cat $notifyfile)
        fi
    fi
    
    if [[ -n $profilefilename && -f $profilefilename ]]
    then
        unset notifyfile
        export TAP_PROFILE_FILE_NAME=$profilefilename
        sed -i '/TAP_PROFILE_FILE_NAME/d' $HOME/.env
        printf "\nTAP_PROFILE_FILE_NAME=$TAP_PROFILE_FILE_NAME" >> $HOME/.env

        local confirmed=''
        if [[ $SILENTMODE != 'YES' ]]
        then            
            while true; do
                read -p "Review the file and confirm to continue? [y/n] " yn
                case $yn in
                    [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                    [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                    * ) echo "Please answer y or n.";
                esac
            done
        fi

        if [[ $confirmed == 'n' ]]
        then
            returnOrexit || return 1
        fi

        printf "\n\nChecking installed tap package version....."
        local tapPackageVersion=$(tanzu package available list tap.tanzu.vmware.com --namespace tap-install -o json | jq -r '[ .[] | {version: .version, released: .["released-at"]|split(" ")[0]} ] | sort_by(.released) | reverse[0] | .version')
        printf "found $tapPackageVersion\n\n"
        if [[ -z $tapPackageVersion ]]
        then
            printf "\n${redcolor}ERROR: package version could not be retrieved.${normalcolor}\n"
            printf "Execute below command manually:\n"
            printf "tanzu package install tap -p tap.tanzu.vmware.com -v {TAP_PACKAGE_VERSION} --values-file $profilefilename -n tap-install --poll-interval 5s --poll-timeout 15m0s\n"
            printf "${yellowcolor}Where TAP_PACKAGE_VERSION is the version of the tap.tanzu.vmware.com you want to install${normalcolor}\n"
            returnOrexit || return 1
        else
            if [[ -n $TAP_PACKAGE_VERSION && "$TAP_PACKAGE_VERSION" != "$tapPackageVersion" ]]
            then
                printf "\n${redcolor}WARN: .env variable TAP_PACKAGE_VERSION=$TAP_PACKAGE_VERSION does not match version installed on cluster tapPackageVersion=$tapPackageVersion.${normalcolor}\n"
                while true; do
                    read -p "confirm to continue install profile using version $tapPackageVersion? [y/n] " yn
                    case $yn in
                        [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                        [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; returnOrexit || return 1;;
                        * ) echo "Please answer y or n.";
                    esac
                done
            fi
        fi

        printf "\ninstalling tap.tanzu.vmware.com in namespace tap-install...\n"
        #printf "DEBUG: tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_PACKAGE_VERSION --values-file $profilefilename -n tap-install --poll-interval 5s --poll-timeout 15m0s"
        tanzu package install tap -p tap.tanzu.vmware.com -v $tapPackageVersion --values-file $profilefilename -n tap-install --poll-interval 5s --poll-timeout 15m0s

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
                printf "Did not get a Reconcile successful. Received status: $reconcileStatus\n."
                reconcileStatus=''
            fi
            if [[ $reconcileStatus == *@("succeeded")* ]]
            then
                printf "Received status: $reconcileStatus\n."
                break
            fi
            printf "wait 2m before checking again ($count out of 4 max)...."
            ((count=$count+1))
            sleep 2m
        done
        printf "\nWait 1m before listing the packages installed....\n"
        sleep 1m
        printf "\nList packages status....\n"
        sleep 1
        tanzu package installed list -A

        confirmed='n'
        while true; do
            read -p "Please confirm if reconcile for needed packages are successful? [y/n] " yn
            case $yn in
                [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                [Nn]* ) printf "You confirmed no.\n"; break;;
                * ) echo "Please answer y or n.";
            esac
        done

        printf "\n\n"
        
        local isexist=$(cat $profilefilename | grep -w 'grype:$')
        if [[ -n $isexist ]]
        then
            printf "\nDetected user input for scanning functionlity (grype). Metadata store needs to be wired with TAP-GUI in order for scan result to get displayed in the GUI supply chain."
            printf "\nCreating readonly service account name 'metadata-store-read-client' and rolebindings for it...\n"
            kubectl apply -f $HOME/binaries/templates/tap-metadata-store-readonly-sa.yaml
            printf "\nCreated===\nServiceAccount: metadata-store-read-client in NS: metadata-store\nClusterRoleBinding: metadata-store-ready-only with RoleRef: metadata-store-read-only for SA: metadata-store-read-client\n"
            sleep 1
            printf "\nGetting access token for the above created SA..."
            local METADATA_STORE_ACCESS_TOKEN=$(kubectl get secrets -n metadata-store -o jsonpath="{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='metadata-store-read-client')].data.token}" | base64 -di)
            if [[ -n $METADATA_STORE_ACCESS_TOKEN ]]
            then
                printf "OBTAINED METADATA_STORE_ACCESS_TOKEN.\nSee below:\n"
                echo $METADATA_STORE_ACCESS_TOKEN
                printf "\n\nReplacing TAPGUI_READONLY_CLIENT_SA_TOKEN in $profilefilename file with the access token...\n"
                local replaceText='TAPGUI_READONLY_CLIENT_SA_TOKEN'
                awk -v old=$replaceText -v new="$METADATA_STORE_ACCESS_TOKEN" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' $profilefilename > $profilefilename.tmp && mv $profilefilename.tmp $profilefilename
                sleep 1
                printf "\n$profilefilename file updated with the access token...\n"
                sleep 1
                printf "\nUpdating TAP $TAP_VERSION to reflect this change...\n"
                tanzu package installed update tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file $profilefilename -n tap-install
                printf "\nWaiting 20s..."
                sleep 20
            else
                printf "\n${redcolor}ERROR: Failed to retrieve metadata store access token. Please maniually update the file: $profilefilename in section tap_gui.app_config.proxy.metadata-store.headers.Authorization ${normalcolor}\n"
                sleep 1
            fi
            sleep 1
            printf "DONE.\n"
        fi


        if [[ $confirmed == 'y' ]]
        then
            printf "\nExtracting ip of the load balancer...."
            lbip=$(kubectl get svc -n tanzu-system-ingress -o json | jq -r '.items[] | select(.spec.type == "LoadBalancer" and .metadata.name == "envoy") | .status.loadBalancer.ingress[0].ip')
            if [[ -z $lbip || $lbip == null ]]
            then
                lbip=$(kubectl get svc -n tanzu-system-ingress -o json | jq -r '.items[] | select(.spec.type == "LoadBalancer" and .metadata.name == "envoy") | .status.loadBalancer.ingress[0].hostname')
                lbip=$(dig $lbip +short)
            fi
            printf "IP: $lbip"
            printf "\n"
            printf "${bluecolor}use this ip to create A record in the DNS zone or update profile with this ip if using xip.io or nip.io ${normalcolor}\n"
            printf "${bluecolor}To update run the below command: ${normalcolor}\n"
            printf "${bluecolor}tanzu package installed update tap -v $TAP_PACKAGE_VERSION --values-file $profilefilename -n tap-install${normalcolor}\n"

            export INSTALL_TAP_PROFILE='COMPLETED'
            sed -i '/INSTALL_TAP_PROFILE/d' $HOME/.env
            printf "\nINSTALL_TAP_PROFILE=COMPLETED\n" >> $HOME/.env
            printf "\n\n********TAP profile deployment....COMPLETE**********\n\n\n" 
            sleep 3
        fi                  
    fi
}
