#!/bin/bash

export $(cat /root/.env | xargs)

if [[ ! -f $HOME/binaries/scripts/returnOrexit.sh ]]
then
    if [[ ! -d  "$HOME/binaries/scripts" ]]
    then
        mkdir -p $HOME/binaries/scripts
    fi
    printf "\n\n************Downloading Common Scripts**************\n\n"
    curl -L https://raw.githubusercontent.com/alinahid477/common-merlin-scripts/main/scripts/download-common-scripts.sh -o $HOME/binaries/scripts/download-common-scripts.sh
    chmod +x $HOME/binaries/scripts/download-common-scripts.sh
    $HOME/binaries/scripts/download-common-scripts.sh tap scripts
    sleep 1
    if [[ -n $BASTION_HOST ]]
    then
        $HOME/binaries/scripts/download-common-scripts.sh bastion scripts/bastion
        sleep 1
    fi
    printf "\n\n\n///////////// COMPLETED //////////////////\n\n\n"
    printf "\n\n"
fi

printf "\n\nsetting executable permssion to all binaries sh\n\n"
ls -l $HOME/binaries/*.sh | awk '{print $9}' | xargs chmod +x
ls -l $HOME/binaries/scripts/*.sh | awk '{print $9}' | xargs chmod +x

source $HOME/binaries/scripts/returnOrexit.sh
source $HOME/binaries/scripts/color-file.sh
source $HOME/binaries/scripts/init-prechecks.sh


printf "\n\n\n***********Checking kubeconfig...*************\n"
sleep 1
if [[ ! -f $HOME/.kube/config ]]
then
    printf "\n\nNo kubeconfig found in $HOME/.kube/config. Would you like to create one:\n"
    while true; do
        read -p "which k8s cluster would you like to create? [aks, none]: " inp
        if [[ $inp == 'aks' ]]
        then
            source $HOME/binaries/wizards/createakscluster.sh
            createAKSCluster
            break
        else 
            if [[ $inp == 'none' ]]
            then
                exit 1
            else
                printf "Invalid input given.\nEither add config file in .kube dir of this dir OR provide a valid value for cluster create.\n"
            fi
        fi        
    done
else
    printf "\n\nExisting kubeconfig file found. Checkings number of contexts..."
    numberofcontexts=$(kubectl config get-contexts --no-headers -o name | wc -l)
    printf "$numberofcontexts\n"
    if [[ $numberofcontexts -gt 1 ]]
    then
        printf "More than 1 context found.\navailable contexts are....\n"
        kubectl config get-contexts
        while true; do
            read -p "input the name of the context for TAP deployment: " inp
            if [[ -z $inp ]]
            then
                printf "empty value is not allowed.\n"
            else 
                kubectl config use-context $inp && printf "context switched to $inp\n" || exit 1
                break
            fi        
        done
    fi   
fi

printf "\n\n************Checking cloud CLI if needed**************\n\n"
source $HOME/binaries/scripts/install-cloud-cli.sh
if [[ -n $AWS_ACCESS_KEY_ID ]]
then
    # aks cluster does NOT require az cli to be present
    # BUT eks cluster does. Hence installing aws cli
    installAWSCLI
fi



if [[ -n $TKG_VSPHERE_SUPERVISOR_ENDPOINT ]]
then

    IS_KUBECTL_VSPHERE_EXISTS=$(kubectl vsphere)
    if [ -z "$IS_KUBECTL_VSPHERE_EXISTS" ]
    then 
        printf "\n\nkubectl vsphere not installed.\nChecking for binaries...\n"
        IS_KUBECTL_VSPHERE_BINARY_EXISTS=$(ls ~/binaries/ | grep kubectl-vsphere)
        if [ -z "$IS_KUBECTL_VSPHERE_BINARY_EXISTS" ]
        then            
            printf "\n\nDid not find kubectl-vsphere binary in ~/binaries/.\nDownloding in ~/binaries/ directory...\n"
            if [[ -n $BASTION_HOST ]]
            then
                ssh -i /root/.ssh/id_rsa -4 -fNT -L 443:$TKG_VSPHERE_SUPERVISOR_ENDPOINT:443 $BASTION_USERNAME@$BASTION_HOST
                curl -kL https://localhost/wcp/plugin/linux-amd64/vsphere-plugin.zip -o ~/binaries/vsphere-plugin.zip
                sleep 2
                fuser -k 443/tcp
            else 
                curl -kL https://$TKG_VSPHERE_SUPERVISOR_ENDPOINT/wcp/plugin/linux-amd64/vsphere-plugin.zip -o ~/binaries/vsphere-plugin.zip
            fi            
            unzip ~/binaries/vsphere-plugin.zip -d ~/binaries/vsphere-plugin/
            mv ~/binaries/vsphere-plugin/bin/kubectl-vsphere ~/binaries/
            rm -R ~/binaries/vsphere-plugin/
            rm ~/binaries/vsphere-plugin.zip
            
            printf "\n\nkubectl-vsphere is now downloaded in ~/binaries/...\n"
        else
            printf "kubectl-vsphere found in binaries dir...\n"
        fi
        printf "\n\nAdjusting the dockerfile to incluse kubectl-binaries...\n"
        sed -i '/COPY binaries\/kubectl-vsphere \/usr\/local\/bin\//s/^# //' ~/Dockerfile
        sed -i '/RUN chmod +x \/usr\/local\/bin\/kubectl-vsphere/s/^# //' ~/Dockerfile

        printf "\n\nDockerfile is now adjusted with kubectl-vsphre.\n\n"
        printf "\n\nPlease rebuild the docker image and run again (or ./start.sh merlin-tap forcebuild).\n\n"
        exit 1
    else
        printf "\nfound kubectl-vsphere...\n"
    fi

    printf "\n\n\n**********vSphere Cluster login...*************\n"
    sleep 2
    export KUBECTL_VSPHERE_PASSWORD=$(echo $TKG_VSPHERE_PASSWORD | xargs)


    EXISTING_JWT_EXP=$(awk '/users/{flag=1} flag && /'$TKG_VSPHERE_CLUSTER_ENDPOINT'/{flag2=1} flag2 && /token:/ {print $NF;exit}' /root/.kube/config | jq -R 'split(".") | .[1] | @base64d | fromjson | .exp')

    if [ -z "$EXISTING_JWT_EXP" ]
    then
        EXISTING_JWT_EXP=$(date  --date="yesterday" +%s)
        # printf "\n SET EXP DATE $EXISTING_JWT_EXP"
    fi
    CURRENT_DATE=$(date +%s)

    if [ "$CURRENT_DATE" -gt "$EXISTING_JWT_EXP" ]
    then
        printf "\n\n\n***********Login into cluster...*************\n"
        sleep 1
        rm /root/.kube/config
        rm -R /root/.kube/cache
        if [[ -z $BASTION_HOST ]]
        then
            kubectl vsphere login --tanzu-kubernetes-cluster-name $TKG_VSPHERE_CLUSTER_NAME --server $TKG_VSPHERE_SUPERVISOR_ENDPOINT --insecure-skip-tls-verify -u $TKG_VSPHERE_USERNAME
            kubectl config use-context $TKG_VSPHERE_CLUSTER_NAME
        else
            printf "\n\n\n***********Creating Tunnel through bastion $BASTION_USERNAME@$BASTION_HOST ...*************\n"            
            ssh-keyscan $BASTION_HOST > /root/.ssh/known_hosts
            printf "\nssh -i /root/.ssh/id_rsa -4 -fNT -L 443:$TKG_VSPHERE_SUPERVISOR_ENDPOINT:443 $BASTION_USERNAME@$BASTION_HOST\n"
            ssh -i /root/.ssh/id_rsa -4 -fNT -L 443:$TKG_VSPHERE_SUPERVISOR_ENDPOINT:443 $BASTION_USERNAME@$BASTION_HOST
            sleep 1
            printf "\n\n\n***********Authenticating to cluster $TKG_VSPHERE_CLUSTER_NAME-->IP:$TKG_VSPHERE_CLUSTER_ENDPOINT  ...*************\n"
            kubectl vsphere login --tanzu-kubernetes-cluster-name $TKG_VSPHERE_CLUSTER_NAME --server kubernetes --insecure-skip-tls-verify -u $TKG_VSPHERE_USERNAME
            sleep 1
            printf "\n\n\n***********Adjusting your kubeconfig...*************\n"
            sed -i 's/kubernetes/'$TKG_VSPHERE_SUPERVISOR_ENDPOINT'/g' ~/.kube/config
            kubectl config use-context $TKG_VSPHERE_CLUSTER_NAME

            sed -i '0,/'$TKG_VSPHERE_CLUSTER_ENDPOINT'/s//kubernetes/' ~/.kube/config
            ssh -i /root/.ssh/id_rsa -4 -fNT -L 6443:$TKG_VSPHERE_CLUSTER_ENDPOINT:6443 $BASTION_USERNAME@$BASTION_HOST
            printf "DONE\n\n\n"
            sleep 2
        fi
    else
        printf "\n\n\nCuurent kubeconfig has not expired. Using the existing one found at .kube/config\n"
        if [[ -n $BASTION_HOST ]]
        then
            printf "\n\n\n***********Creating K8s endpoint Tunnel through bastion $BASTION_USERNAME@$BASTION_HOST ...*************\n"
            sleep 1
            ssh -i /root/.ssh/id_rsa -4 -fNT -L 6443:$TKG_VSPHERE_CLUSTER_ENDPOINT:6443 $BASTION_USERNAME@$BASTION_HOST
            printf "DONE\n\n\n"
            sleep 2
        fi
    fi
else
    printf "\n\n\n**********login based on kubeconfig...*************\n"
    sleep 1
    if [[ -n $BASTION_HOST ]]
    then
        printf "Bastion host specified...\n"
        sleep 1
        printf "Extracting server url...\n"
        serverurl=$(awk '/server/ {print $NF;exit}' /root/.kube/config | awk -F/ '{print $3}' | awk -F: '{print $1}')
        printf "server url: $serverurl\n"
        printf "Extracting port...\n"
        port=$(awk '/server/ {print $NF;exit}' /root/.kube/config | awk -F/ '{print $3}' | awk -F: '{print $2}')
        if [[ -z $port ]]
        then
            port=80
        fi
        printf "port: $port\n"
        printf "\n\n\n***********Creating K8s endpoint Tunnel through bastion $BASTION_USERNAME@$BASTION_HOST ...*************\n"
        ssh -i /root/.ssh/id_rsa -4 -fNT -L $port:$serverurl:$port $BASTION_USERNAME@$BASTION_HOST
        printf "DONE\n\n\n"
        sleep 2
    fi
fi




printf "\n\n************Checking connected k8s cluster**************\n\n"
sleep 1
kubectl get ns
printf "\n"
while true; do
    read -p "Confirm if you are seeing expected namespaces to proceed further? [y/n]: " yn
    case $yn in
        [Yy]* ) printf "\nyou confirmed yes\n"; break;;
        [Nn]* ) printf "\n\nYou said no. \n\nExiting...\n\n"; exit 1;;
        * ) echo "Please answer y or n.";;
    esac
done

printf "\n\n************Checking Tanzu CLI binaries**************\n\n"
source $HOME/binaries/scripts/install-tanzu-cli.sh
installTanzuCLI
printf "DONE\n\n\n"


if [[ $INSTALL_TANZU_CLUSTER_ESSENTIAL == 'COMPLETED' ]]
then
    # The purpose for calling installClusterEssential here again 
    # is so that the script can perform cp $HOME/tanzu-cluster-essentials/kapp /usr/local/bin/kapp 

    # The purpose for this code block here is NOT to trigger re-deploy of cluster-essential in k8s cluster
    # BUT to only add kapp in /usr/local/bin/kapp
    
    printf "\n\n************Checking Cluster Essential Kapp binaries**************\n\n"
    source $HOME/binaries/scripts/install-cluster-essential.sh
    installClusterEssential
    printf "DONE\n\n\n"
fi





printf "\nUsage merlin --help\n"

cd ~
/bin/bash