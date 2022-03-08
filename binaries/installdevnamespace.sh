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


source $HOME/binaries/scripts/extract-and-take-input.sh


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

    local confirmed=''
    if [[ -n $PROFILE_FILE_NAME ]]
    then
        isexist=$(cat $PROFILE_FILE_NAME | grep -w 'gitops:$')        
        confirmed='y'
    else
        printf "Hint: ${bluecolor}If you have configured supply chain using GIT url and is automating CD through supply chain it is likely that you are using GitOps.\n"
        printf "OR if in the profile file you have mentioned ssh_secret for GitOps then you are using GitOps\n"
        printf "Below question is to determine whether to create ssh_secret for gitops${normalcolor}"
        while true; do
            read -p "Are you using GitOps? [y/n] " yn
            case $yn in
                [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                * ) echo "Please answer yes or no.";
            esac
        done
    fi
    
    if [[ $confirmed == 'y' ]]
    then
        if [[ ! -f $HOME/.git-ops/identity || ! -f $HOME/.git-ops/identity.pub ]]
        then
            printf "Identity files for git repository (public and private key files) not found.\n"
            printf "If you already have one for git repository confirm 'n' and place the files with name identity and identity.pub in $HOME/.git-ops/ directory.\n"
            printf "Alternatively, confirm y to create a new one.\n"
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
        sleep 3

        printf "Here's identity.pub\n"
        cat $HOME/.git-ops/identity.pub

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
            printf "Hint: ${bluecolor}Gitrepo host name.${normalcolor}. eg: github.com, bitbucket.org\n"

            local gitprovidername=''
            while [[ -z $gitprovidername ]]; do
                read -p "Input the hostname of they git repo? [y/n] " gitprovidername
                if [[ -z $gitprovidername ]]
                then
                    printf "WARN: empty value not allowed.\n"
                fi
            done

            printf "Creating known_hosts file for $gitprovidername..."
            ssh-keyscan $gitprovidername > $HOME/.git-ops/known_hosts
            printf "COMPLETE\n"

            printf "Generating known_hosts file for $gitprovidername..."
            local tmpCmdFile=/tmp/devnamespacecmdgitssh.tmp
            local cmdTemplate="kubectl create secret generic <GITOPS-SECRET-NAME> --from-file=$HOME/.git-ops/identity --from-file=$HOME/.git-ops/identity --from-file=$HOME/.git-ops/known_hosts"

            echo $cmdTemplate > $tmpCmdFile
            extractVariableAndTakeInput $tmpCmdFile
            cmdTemplate=$(cat $tmpCmdFile)


            printf "\nCreating new secret for private git repository access, named: $GITOPS_SECRET_NAME..."
            $(echo $cmdTemplate) && printf "OK" || printf "FAILED"
            printf "\n"        
        fi
    fi

    

    local tmpCmdFile=/tmp/devnamespacecmd.tmp
    local cmdTemplate="tanzu secret registry add <TARGET-REGISTRY-CREDENTIALS-SECRET-NAME> --server <PVT_REGISTRY_SERVER> --username <PVT_REGISTRY_USERNAME> --password <PVT_REGISTRY_PASSWORD> --yes --namespace ${namespacename}"

    echo $cmdTemplate > $tmpCmdFile
    extractVariableAndTakeInput $tmpCmdFile
    cmdTemplate=$(cat $tmpCmdFile)

    printf "\nCreating new secret for private registry with name: registry-credentials..."
    $(echo $cmdTemplate) && printf "OK" || printf "FAILED"
    printf "\n"

    printf "\nCreating RBAC, SA for associating TAP and registry with name: default..."
    kubectl apply -n $namespacename -f $HOME/binaries/templates/workload-ns-setup.yaml && printf "OK" || printf "FAILED"
    printf "\n"

    printf "\n\n**** Developer namespace: $namespacename setup...COMPLETE\n\n\n"
}



createDevNS