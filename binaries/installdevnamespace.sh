#!/bin/bash


export $(cat /root/.env | xargs)


source $HOME/binaries/scripts/extract-and-take-input.sh
source $HOME/binaries/scripts/select-from-available-options.sh

createDevNS () {
    local bluecolor=$(tput setaf 4)
    local normalcolor=$(tput sgr0)

    printf "\n*******Starting developer namespace wizard*******\n\n"

    unset namespacename
    while [[ -z $namespacename ]]; do
        read -p "name of the namespace: " namespacename
        if [[ -z $namespacename && ! $namespacename =~ ^[A-Za-z0-9_\-]+$ ]]
        then
            printf "empty or invalid value is not allowed.\n"
        fi
    done

    printf "\nChecking namcespace in the cluster....\n"
    local isexist=$(kubectl get ns | grep "^$namespacename")

    if [[ -n $isexist ]] 
    then
        printf "namespace: $namespacename already exists....Skipping Create New\n"
    else
        printf "namespace: $namespacename does not exist, Creating New...."
        kubectl create ns $namespacename && printf "OK" || printf "FAILED"
        printf "\n"

        isexist=$(kubectl get ns | grep "^$namespacename")
        if [[ -z $isexist ]]
        then
            printf "ERROR: Failed to create namespace: $namespacename\n"
            returnOrexit || return 1
        fi
    fi

    local selectedSupplyChainType=''
    if [[ -n $PROFILE_FILE_NAME ]]
    then
        isexist=$(cat $PROFILE_FILE_NAME | grep -w 'gitops:$')        
        selectedSupplyChainType='gitops'
    else
        local supplyChainTypes=("local_iteration" "local_iteration_with_code_from_git" "gitops")
        selectFromAvailableOptions ${supplyChainTypes[@]}
        ret=$?
        if [[ $ret == 255 ]]
        then
            printf "${redcolor}No selection were made. Remove the entry${normalcolor}\n"
            returnOrexit || return 1
        else
            # selected option
            selectedSupplyChainType=${supplyChainTypes[$ret]}
        fi
    fi
    
    if [[ $selectedSupplyChainType != 'local_iteration' ]]
    then
        if [[ ! -f $HOME/.git-ops/identity || ! -f $HOME/.git-ops/identity.pub ]]
        then
            printf "Identity files for git repository (public and private key files) not found.\n"
            printf "If you already have one for git repository confirm 'n' and place the files with name identity and identity.pub in $HOME/.git-ops/ directory.\n"
            printf "Otherwise, confirm y to create a new one.\n"
            while true; do
                read -p "Would you like to create identity file for your git repo? [y/n] " yn
                case $yn in
                    [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                    [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                    * ) echo "Please answer yes or no.";
                esac
            done

            if [[ $confirmed == 'y' ]]
            then
                local keyemail=''
                while [[ -z $keyemail ]]; do
                    read -p "Input Email or Username for generating public and private key pair for gitops: " keyemail
                    if [[ -z $keyemail ]]
                    then
                        printf "WARN: empty value not allowed.\n"
                    fi
                done
                printf "Generating key pair..."
                ssh-keygen -f $HOME/.git-ops/identity -q -t rsa -b 4096 -C "$keyemail" -N ""
                sleep 2
                printf "COMPLETE\n"
            fi
        else
            printf "Git repo identity keypair for GitOps found in $HOME/.git-ops/.\n"
        fi

        printf "${bluecolor}Please make sure that identity.pub exists in the gitrepo.\n"
        printf "eg: for bitbucket it is in: https://bitbucket.org/<projectname>/<reponame>/admin/addon/admin/pipelines/ssh-keys\n"
        printf "OR for githun it is in: https://github.com/<username>/<reponame>/settings/keys/new${normalcolor}\n"
        sleep 2

        printf "Here's identity.pub\n"
        cat $HOME/.git-ops/identity.pub
        sleep 2
        printf "\n\n"
        while true; do
            read -p "Confirm to continue to create secret in k8s cluster using the Git repo keypair? [y/n] " yn
            case $yn in
                [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                * ) echo "Please answer yes or no.";
            esac
        done

        if [[ $confirmed == 'y' ]]
        then
            if [[ ! -f $HOME/.git-ops/known_hosts ]]
            then
                printf "Hint: ${bluecolor}Gitrepo host name. eg: github.com, bitbucket.org${normalcolor}\n"

                local gitprovidername=''
                while [[ -z $gitprovidername ]]; do
                    read -p "Input the hostname of they git repo: " gitprovidername
                    if [[ -z $gitprovidername ]]
                    then
                        printf "WARN: empty value not allowed.\n"
                    fi
                done

                printf "Creating known_hosts file for $gitprovidername..."
                ssh-keyscan $gitprovidername > $HOME/.git-ops/known_hosts || returnOrexit || return 1
                printf "COMPLETE\n"
            fi

            if [[ $selectedSupplyChainType == 'local_iteration_with_code_from_git' ]]
            then
                local tmpCmdFile=/tmp/devnamespacecmdgitssh.tmp
                local cmdTemplate="kubectl create secret generic <GITOPS-SECRET-NAME> --from-file=$HOME/.git-ops/identity --from-file=$HOME/.git-ops/identity.pub --from-file=$HOME/.git-ops/known_hosts --namespace ${namespacename}"

                echo $cmdTemplate > $tmpCmdFile
                extractVariableAndTakeInput $tmpCmdFile
                cmdTemplate=$(cat $tmpCmdFile)

                export $(cat $HOME/.env | xargs)

                printf "\nCreating new secret for private git repository access, named: $GITOPS_SECRET_NAME..."
                $(echo $cmdTemplate) && printf "OK" || printf "FAILED"
                printf "\n\n\n"
                sleep 4
            fi
            if [[ $selectedSupplyChainType == 'gitops' ]]
            then
                export GIT_SERVER_HOST=$gitprovidername
                export GIT_SSH_PRIVATE_KEY=$(cat $HOME/.git-ops/identity | base64 -w 0)
                export GIT_SSH_PUBLIC_KEY=$(cat $HOME/.git-ops/identity.pub | base64 -w 0)
                export GIT_SERVER_HOST_FILE=$(cat $HOME/.git-ops/known_hosts | base64 -w 0)

                cp $HOME/binaries/templates/gitops-secret.yaml /tmp/gitops-secret-$GITOPS_SECRET_NAME.yaml
                extractVariableAndTakeInput /tmp/gitops-secret-$GITOPS_SECRET_NAME.yaml

                export $(cat $HOME/.env | xargs)

                printf "\nApplying kubectl for new secret for private git repository access, named: $GITOPS_SECRET_NAME..."
                kubectl apply -f /tmp/gitops-secret-$GITOPS_SECRET_NAME.yaml --namespace $namespacename && printf "OK" || printf "FAILED"
                printf "\n\n\n"
                sleep 3
                unset GIT_SERVER_HOST
                unset GIT_SSH_PRIVATE_KEY
                unset GIT_SSH_PUBLIC_KEY
                unset GIT_SERVER_HOST_FILE
            fi
        fi
    fi

    

    local tmpCmdFile=/tmp/devnamespacecmd.tmp
    local cmdTemplate="tanzu secret registry add <TARGET-REGISTRY-CREDENTIALS-SECRET-NAME> --server <PVT_REGISTRY_SERVER> --username <PVT_REGISTRY_USERNAME> --password <PVT_REGISTRY_PASSWORD> --yes --namespace ${namespacename}"

    echo $cmdTemplate > $tmpCmdFile
    extractVariableAndTakeInput $tmpCmdFile
    cmdTemplate=$(cat $tmpCmdFile)

    printf "\nCreating new secret for private registry with name: $TARGET_REGISTRY_CREDENTIALS_SECRET_NAME..."
    $(echo $cmdTemplate) && printf "OK" || printf "FAILED"
    printf "\n"

    printf "\nCreating RBAC, SA for associating TAP and registry with name: default..."
    kubectl apply -n $namespacename -f $HOME/binaries/templates/workload-ns-setup.yaml && printf "OK" || printf "FAILED"
    printf "\n"

    printf "\n\n**** Developer namespace: $namespacename setup...COMPLETE\n\n\n"
}



createDevNS