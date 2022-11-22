#!/bin/bash


export $(cat $HOME/.env | xargs)

source $HOME/binaries/scripts/returnOrexit.sh
source $HOME/binaries/tapscripts/extract-and-take-input.sh
source $HOME/binaries/scripts/select-from-available-options.sh
source $HOME/binaries/scripts/create-secrets.sh

createDevNS () {
    local bluecolor=$(tput setaf 4)
    local normalcolor=$(tput sgr0)
    local tapvaluesfile=$1
    local confirmed=''

    if [[ -z $tapvaluesfile ]]
    then
        if [[ -n $TAP_PROFILE_FILE_NAME ]] 
        then
            tapvaluesfile=$TAP_PROFILE_FILE_NAME
        else
            while [[ -z $tapvaluesfile ]]; do
                printf "\nHINT: requires full path of the tap values file. (eg: /root/configs/tap-profile-my.yaml)\n"
                read -p "full path of the tap values file: " tapvaluesfile
                if [[ -z $tapvaluesfile || ! -f $tapvaluesfile ]]
                then
                    printf "empty or invalid value is not allowed.\n"
                fi
            done        
        fi
    fi

    printf "\nSet Tap Values File: $tapvaluesfile\n"

    while true; do
        read -p "confirm to continue? [y/n] " yn
        case $yn in
            [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
            [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
            * ) echo "Please answer y or n.";
        esac
    done

    if [[ $confirmed == 'n' ]]
    then
        returnOrexit || return 1
    fi

    printf "\n*******Starting developer namespace wizard*******\n\n"

    local namespacename=''
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
    if [[ -n $tapvaluesfile ]]
    then
        isexist=$(cat $tapvaluesfile | grep -w 'gitops:$')
        if [[ -n $isexist ]]
        then
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
    fi
    
    if [[ $selectedSupplyChainType != 'local_iteration' ]]
    then
        ###
        # the below commented out section is not needed now because 
        # I have not figured out yet with ootb TAP supply chain how to pass 2 different git secrets 1 for pvt-source-repo and 1 for gitops-repo.
        # if I can figure it out then will unblock the below for gitops-repo BUT
        # I will still need to figure out a way to add pvt-git-repo secret to default sa. 
        # (which I have solved for cartographer. BUT not yet for TAP. this is because TAP ootb supply chain are weird and works with static set to names which are not well documented)
        ###
        # if [[ ! -f $HOME/.git-ops/identity || ! -f $HOME/.git-ops/identity.pub ]]
        # then
        #     printf "Identity files for git repository (public and private key files) not found.\n"
        #     printf "If you already have one for git repository confirm 'n' and place the files with name identity and identity.pub in $HOME/.git-ops/ directory.\n"
        #     printf "Otherwise, confirm y to create a new one.\n"
        #     while true; do
        #         read -p "Would you like to create identity file for your git repo? [y/n] " yn
        #         case $yn in
        #             [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
        #             [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
        #             * ) echo "Please answer y or n.";
        #         esac
        #     done

        #     if [[ $confirmed == 'y' ]]
        #     then
        #         local keyemail=''
        #         while [[ -z $keyemail ]]; do
        #             read -p "Input Email or Username for generating public and private key pair for gitops: " keyemail
        #             if [[ -z $keyemail ]]
        #             then
        #                 printf "WARN: empty value not allowed.\n"
        #             fi
        #         done
        #         printf "Generating key pair..."
        #         ssh-keygen -f $HOME/.git-ops/identity -q -t rsa -b 4096 -C "$keyemail" -N ""
        #         sleep 2
        #         printf "COMPLETE\n"
        #     fi
        # else
        #     printf "Git repo identity keypair for GitOps found in $HOME/.git-ops/.\n"
        # fi

        # printf "${bluecolor}Please make sure that identity.pub exists in the gitrepo.\n"
        # printf "eg: for bitbucket it is in: https://bitbucket.org/<projectname>/<reponame>/admin/addon/admin/pipelines/ssh-keys\n"
        # printf "OR for githun it is in: https://github.com/<username>/<reponame>/settings/keys/new${normalcolor}\n"
        # sleep 2

        # printf "Here's identity.pub\n"
        # cat $HOME/.git-ops/identity.pub
        # sleep 2
        # printf "\n\n"
        # while true; do
        #     read -p "Confirm to continue to create secret in k8s cluster using the Git repo keypair? [y/n] " yn
        #     case $yn in
        #         [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
        #         [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
        #         * ) echo "Please answer y or n.";
        #     esac
        # done
        confirmed='y'
        if [[ $confirmed == 'y' ]]
        then
            # if [[ ! -f $HOME/.git-ops/known_hosts ]]
            # then
            #     printf "Hint: ${bluecolor}Gitrepo host name. eg: github.com, bitbucket.org${normalcolor}\n"

            #     local gitprovidername=''
            #     while [[ -z $gitprovidername ]]; do
            #         read -p "Input the hostname of they git repo: " gitprovidername
            #         if [[ -z $gitprovidername ]]
            #         then
            #             printf "WARN: empty value not allowed.\n"
            #         fi
            #     done

            #     printf "Creating known_hosts file for $gitprovidername..."
            #     ssh-keyscan $gitprovidername > $HOME/.git-ops/known_hosts || returnOrexit || return 1
            #     printf "COMPLETE\n"
            # fi

            # if [[ $selectedSupplyChainType == 'local_iteration_with_code_from_git' ]]
            # then
            #     local tmpCmdFile=/tmp/devnamespacecmdgitssh.tmp
            #     local cmdTemplate="kubectl create secret generic <GITOPS-SECRET-NAME> --from-file=$HOME/.git-ops/identity --from-file=$HOME/.git-ops/identity.pub --from-file=$HOME/.git-ops/known_hosts --namespace ${namespacename}"

            #     echo $cmdTemplate > $tmpCmdFile
            #     extractVariableAndTakeInput $tmpCmdFile
            #     cmdTemplate=$(cat $tmpCmdFile)

            #     export $(cat $HOME/.env | xargs)

            #     printf "\nCreating new secret for private git repository access..."
            #     $(echo $cmdTemplate) && printf "OK" || printf "FAILED"
            #     printf "\n\n\n"
            #     sleep 4
            # fi
            if [[ $selectedSupplyChainType == 'gitops' || $selectedSupplyChainType == 'local_iteration_with_code_from_git' ]]
            then
                # export GIT_SERVER_HOST=$gitprovidername
                # export GIT_SSH_PRIVATE_KEY=$(cat $HOME/.git-ops/identity | base64 -w 0)
                # export GIT_SSH_PUBLIC_KEY=$(cat $HOME/.git-ops/identity.pub | base64 -w 0)
                # export GIT_SERVER_HOST_FILE=$(cat $HOME/.git-ops/known_hosts | base64 -w 0)

                printf "\nCreating ssh secret for git repo access (both private source and gitops repo)...\n"

                # cp $HOME/binaries/templates/tap-git-secret.yaml /tmp/tap-git-secret.yaml
                # extractVariableAndTakeInput /tmp/tap-git-secret.yaml

                export $(cat $HOME/.env | xargs)

                # printf "\nApplying kubectl for new secret for private git repository access..."
                # kubectl apply -f /tmp/tap-git-secret.yaml --namespace $namespacename && printf "OK" || printf "FAILED"
                # printf "\n\n\n"
                # sleep 3

                createGitSSHSecret $namespacename

                # unset GIT_SERVER_HOST
                # unset GIT_SSH_PRIVATE_KEY
                # unset GIT_SSH_PUBLIC_KEY
                # unset GIT_SERVER_HOST_FILE
            fi
        fi
    fi

    
    printf "\nCreating registry credential for pvt registry access...\n"
    local tmpCmdFile=/tmp/devnamespacecmd.tmp
    local cmdTemplate="tanzu secret registry add <TARGET-REGISTRY-CREDENTIALS-SECRET-NAME> --server <PVT_REGISTRY_SERVER> --username <PVT_REGISTRY_USERNAME> --password <PVT_REGISTRY_PASSWORD> --yes --namespace ${namespacename}"

    echo $cmdTemplate > $tmpCmdFile
    extractVariableAndTakeInput $tmpCmdFile
    cmdTemplate=$(cat $tmpCmdFile)

    printf "\nCreating new secret for private registry with name: $TARGET_REGISTRY_CREDENTIALS_SECRET_NAME..."
    $(echo $cmdTemplate) && printf "OK" || printf "FAILED"
    printf "\n"
    rm $tmpCmdFile
    sleep 1

    printf "\nAlso need to create a dockerhub secret called: dockerhubregcred for Dockerhub rate limiting issue. This credential is used for things like maven test tekton pipeline pulling maven base image etc\n"
    confirmed='n'
    while true; do
        read -p "Would you like to create docker hub secret called 'dockerhubregcred' now? [y/n] " yn
        case $yn in
            [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
            [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
            * ) echo "Please answer y or n.";
        esac
    done
    if [[ $confirmed == 'y' ]]
    then
        local tmpCmdFile=/tmp/devnamespacecmd.tmp
        local cmdTemplate="kubectl create secret docker-registry dockerhubregcred --docker-server=https://index.docker.io/v2/ --docker-username=<DOCKERHUB_USERNAME> --docker-password=<DOCKERHUB_PASSWORD> --docker-email=your@email.com --namespace ${namespacename}"

        echo $cmdTemplate > $tmpCmdFile
        extractVariableAndTakeInput $tmpCmdFile
        cmdTemplate=$(cat $tmpCmdFile)

        printf "\nCreating new secret with name: dockerhubregcred..."
        $(echo $cmdTemplate) && printf "OK" || printf "FAILED"
        printf "\n"
    fi
    


    printf "\nGenerating RBAC, SA for associating TAP and registry using name: default..."
    cp $HOME/binaries/templates/workload-ns-setup.yaml /tmp/workload-ns-setup-$namespacename.yaml
    extractVariableAndTakeInput /tmp/workload-ns-setup-$namespacename.yaml

    printf "\n"

    printf "\nCreating RBAC, RoleBinding and associating SA:default with it along with registry and repo credentials..."
    kubectl apply -n $namespacename -f /tmp/workload-ns-setup-$namespacename.yaml && printf "OK" || printf "FAILED"
    printf "\n"


    isexist=$(cat $tapvaluesfile | grep -w 'grype:$')
    if [[ -n $isexist ]]
    then
        confirmed='n'
        printf "\nDetected user input for scanning functionlity (grype). A 'kind: ScanPolicy' needs to be present in the namespace.\n"
        while true; do
            read -p "Would you create scan policy using $HOME/binaries/templates/tap-scan-policy.yaml file? [y/n] " yn
            case $yn in
                [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                * ) echo "Please answer y or n.";
            esac
        done
        if [[ $confirmed == 'y' ]]
        then
            printf "\nApplying scan policy as per $HOME/binaries/templates/tap-scan-policy.yaml.\nThis is pre-configured for java app and only detects critical level severity. Please change accordingly.\n"
            kubectl apply -f $HOME/binaries/templates/tap-scan-policy.yaml -n $namespacename
            printf "\nScan policy creation ... COMPLETE\n"
        fi
    fi
    
    printf "\nChecking whether it requires tekton pipeline for testing....\n"
    isexist=$(cat $tapvaluesfile | grep -i 'supply_chain: testing')
    if [[ -n $isexist ]]
    then
        printf "\nDetected user input for testing functionlity. Applying a maven test tekton pipeline based on file $HOME/binaries/templates/tap-maven-test-tekton-pipeline.yaml...\n"
        confirmed='n'
        while true; do
            read -p "Would you create maven-test-tekton-pipeline? [y/n] " yn
            case $yn in
                [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                * ) echo "Please answer y or n.";
            esac
        done
        if [[ $confirmed == 'y' ]]
        then
            printf "\nCreating pipeline..\n"
            kubectl apply -f $HOME/binaries/templates/tap-maven-test-tekton-pipeline.yaml -n $namespacename
        fi
    fi

    printf "\n\n**** Developer namespace: $namespacename setup...COMPLETE\n\n\n"
}
