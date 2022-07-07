#!/bin/bash

export $(cat $HOME/.env | xargs)

source $HOME/binaries/scripts/select-from-available-options.sh
source $HOME/binaries/scripts/extract-and-take-input.sh
source $HOME/binaries/scripts/color-file.sh



function saveAndApplyFile () {
    
    local filetype=$1 # required. eg: clusterstore, clusterstack, clusterbuilder etc
    local fileprefix=$2 # required. eg: templatename like kpack-clusterstore,kpack-clusterstack etc
    local filesuffix=$3 # required. eg: default, my-cluster-store etc
    local file=$4 # required. eg: /tmp/kpack-clusterstore.tmp
    local namespace=$5 #optional. eg: applicable for builder, store, stack in a perticular namespace.

    if [[ -n $namespace ]]
    then
        namespace="-n $namespace"
    fi

    local issuccessful='n'
    mv $file $HOME/configs/$fileprefix-$filesuffix.yaml && file=$HOME/configs/$fileprefix-$filesuffix.yaml && printf "SAVED\n" && issuccessful='y'
    if [[ $issuccessful == 'y' ]]
    then
        printf "please review $file\n"
        local confirmed=''
        while true; do
            read -p "Would you like to install $filetype: $filesuffix now? [y/n] " yn
            case $yn in
                [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                * ) echo "Please answer y or n.";
            esac
        done
        if [[ $confirmed == 'y' ]]
        then
            printf "applying $file..."
            # kubectl apply -f $file $namespace && printf "COMPLETED" || printf "FAILED"
            printf "\n"
        elif [[ $confirmed == 'n' ]]
        then
            printf "file is saved ($file). But will not be applied.\n"
        fi
    fi
}


function createKpackClusterStore () {
    
    local configureType=$1 # optional
    if [[ -n $configureType ]]
    then
        configureType="-$configureType"
    fi
    printf "\n\n**** Creating ClusterStore $configureType *****\n\n"

    local clusterstoreTemplateName="kpack-clusterstore$configureType"
    local clusterstoreFile=/tmp/$clusterstoreTemplateName.tmp
    cp $HOME/binaries/templates/$clusterstoreTemplateName.template $clusterstoreFile
    extractVariableAndTakeInput $clusterstoreFile || returnOrexit || return 1

    printf "processing file...\n"
    export $(cat $HOME/.env | xargs)
    sleep 1

    printf "saving file..."
    if [[ $configureType == '-default' ]]
    then
        KPACK_CLUSTERSTORE_NAME='default'
    fi
    if [[ -z $KPACK_CLUSTERSTORE_NAME ]]
    then
        while [[ -z $KPACK_CLUSTERSTORE_NAME ]]; do
            read -p "input value for kpack clusterstore file: " KPACK_CLUSTERSTORE_NAME
            
            if [[ -z $KPACK_CLUSTERSTORE_NAME ]]
            then
                printf "${redcolor}empty value is not allowed.${normalcolor}\n"                
            fi
        done
    fi
    
    saveAndApplyFile "clusterstore" $clusterstoreTemplateName $KPACK_CLUSTERSTORE_NAME $clusterstoreFile
}

function createKpackClusterStack () {
    
    local configureType=$1 # optional
    if [[ -n $configureType ]]
    then
        configureType="-$configureType"
    fi
    printf "\n\n**** Creating ClusterStack $configureType*****\n\n"

    local clusterstackTemplateName="kpack-clusterstack$configureType"
    local clusterstackFile=/tmp/$clusterstackTemplateName.tmp
    cp $HOME/binaries/templates/$clusterstackTemplateName.template $clusterstackFile
    extractVariableAndTakeInput $clusterstackFile || returnOrexit || return 1

    printf "processing file...\n"
    export $(cat $HOME/.env | xargs)
    sleep 1

    printf "saving file..."
    if [[ $configureType == '-default' ]]
    then
        KPACK_CLUSTERSTACK_NAME='base'
    fi
    if [[ -z $KPACK_CLUSTERSTACK_NAME ]]
    then
        while [[ -z $KPACK_CLUSTERSTACK_NAME ]]; do
            read -p "input value for kpack clusterstack file: " KPACK_CLUSTERSTACK_NAME
            
            if [[ -z $KPACK_CLUSTERSTACK_NAME ]]
            then
                printf "${redcolor}empty value is not allowed.${normalcolor}\n"                
            fi
        done
    fi
    
    saveAndApplyFile "clusterstack" $clusterstackTemplateName $KPACK_CLUSTERSTACK_NAME $clusterstackFile
}

function createKpackBuilder () {
    
    local builderType=$1 # Required, Types: clusterbuilder, builder
    local configureType=$2 # optional
    if [[ -n $configureType ]]
    then
        configureType="-$configureType"
    fi

    printf "\n\n**** Creating Builder ($builderType$configureType) *****\n\n"
    
    export $(cat $HOME/.env | xargs)
    sleep 1
    export KPACK_CLUSTERBUILDER_SERVICE_ACCOUNT_NAME=$K8S_SERVICE_ACCOUNT_NAME
    
    local builderTemplateName="kpack-$builderType$configureType"
    local builderFile=/tmp/$builderTemplateName.tmp
    local dynamicVariableNameForBuilderName="KPACK_CLUSTERBUILDER_NAME"
    if [[ $builderType == 'builder' ]]
    then
        dynamicVariableNameForBuilderName="KPACK_BUILDER_NAME"
    fi
    cp $HOME/binaries/templates/$builderTemplateName.template $builderFile
    extractVariableAndTakeInput $builderFile || returnOrexit || return 1

    printf "processing file...\n"
    export $(cat $HOME/.env | xargs)
    sleep 1

    printf "saving file..."
    if [[ $configureType == '-default' ]]
    then
        KPACK_CLUSTERBUILDER_NAME='defaultbuilder'
        KdynamicVariableNameForBuilderName="KPACK_CLUSTERBUILDER_NAME"
    fi
    local inp=''
    if [[ -z ${!dynamicVariableNameForBuilderName} ]]
    then
        while [[ -z $inp ]]; do
            read -p "input value for $inputvar: " inp
            
            if [[ -z $inp ]]
            then
                printf "${redcolor}empty value is not allowed.${normalcolor}\n"                
            fi
        done
        saveAndApplyFile $builderType $builderTemplateName $inp $builderFile
    else
        saveAndApplyFile $builderType $builderTemplateName ${!dynamicVariableNameForBuilderName} $builderFile
    fi    
}


function configureK8sSecretAndServiceAccount () {

    local configureType=$1

    printf "**** Configure K8s docker-registry secret and service account for Kpack ******\n"
    local isexist=''

    local namespace=''
    if [[ $configureType == 'default' ]]
    then
        printf "${yellowcolor}Setting namespace to default.${normalcolor}\n"    
        namespace='default'
    else
        printf "\n\n${greencolor}Configuring namespace...\n${yellowcolor}Type the name of namespace where you would like to create secrets and sa for kpack builder. If the namespace does not exist a new namespace will be created using the provided name.${normalcolor}\n"
    fi
    
    while [[ -z $namespace ]]; do
        read -p "Type the name of namespace: " namespace
        if [[ -z $namespace ]]
        then
            printf "Empty value not allowed.\n"
        fi
    done
    if [[ -n $namespace ]]
    then
        printf "Checking namespace $namespace..."
        isexist=$(kubectl describe ns $namespace)
        if [[ -z $isexist ]]
        then
            printf "Namespace: $namespace ... NOT FOUND\n"
            kubectl create ns $namespace
            printf "CREATED\n"
            sleep 2
        else
            printf "FOUND\n"
            sleep 2
        fi
    fi


    printf "\n\n${greencolor}Configuring container registry secret for kpack...${normalcolor}\n"
    local dockersecretname=''
    while [[ -z $dockersecretname ]]; do
        read -p "Type the name of existing docker-registry secret in $namespace (type 'new' to create new)? " dockersecretname
        if [[ -z $dockersecretname ]]
        then
            printf "Empty value not allowed.\n"
        elif [[ $dockersecretname != 'new' ]]
        then
            printf "Checking secret: $dockersecretname in $namespace..."
            isexist=$(kubectl describe secret $dockersecretname -n $namespace)
            if [[ -z $isexist ]]
            then
                dockersecretname=''
                printf "${yellowcolor}Secret: $dockersecretname not found in namespace: $namespace ${normalcolor}\n"
            fi
        fi
    done
    if [[ $dockersecretname == 'new' ]]
    then
        printf "Require user input for K8s secret of type docker-registry...\n"
        sleep 1
        local tmpCmdFile=/tmp/kubectl-docker-registry-secret-cmd.tmp
        local cmdTemplate="kubectl create secret docker-registry <DOCKER_REGISTRY_SECRET_NAME> --docker-server <DOCKER_REGISTRY_SERVER> --docker-username <DOCKER_REGISTRY_USERNAME> --docker-password <DOCKER_REGISTRY_PASSWORD> --namespace $namespace"

        echo $cmdTemplate > $tmpCmdFile
        extractVariableAndTakeInput $tmpCmdFile
        cmdTemplate=$(cat $tmpCmdFile)
        rm $tmpCmdFile
        printf "\nCreating new K8s secret of type docker-registry..."
        $(echo $cmdTemplate) && printf "OK" || printf "FAILED"
        printf "\n"
    else
        sed -i '/DOCKER_REGISTRY_SECRET_NAME/d' $HOME/.env
        sleep 1
        printf "\nDOCKER_REGISTRY_SECRET_NAME=$dockersecretname\n" >> $HOME/.env
        sleep 1
    fi


    printf "\n\n${greencolor}Configuring git repo secret for kpack...${normalcolor}\n"
    local confirmed=''
    while true; do
        read -p "Would you like to create a secret for git registry in namespace: $namespace? [y/n] " yn
        case $yn in
            [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
            [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
            * ) echo "Please answer y or n.";
        esac
    done    
    if [[ $confirmed == 'y' ]]
    then
        local gitsecretname=''
        while [[ -z $gitsecretname ]]; do
            read -p "Type the name of existing secret in $namespace (type 'new' to create new)? " gitsecretname
            if [[ -z $gitsecretname ]]
            then
                printf "Empty value not allowed.\n"
            elif [[ $gitsecretname != 'new' ]]
            then
                printf "Checking secret: $gitsecretname in $namespace..."
                isexist=$(kubectl describe secret $gitsecretname -n $namespace)
                if [[ -z $isexist ]]
                then
                    gitsecretname=''
                    printf "${yellowcolor}Secret: $gitsecretname not found in namespace: $namespace ${normalcolor}\n"
                fi
            fi
        done
        if [[ $gitsecretname == 'new' ]]
        then
            printf "Require user input k8s secret for git....\n"
            local secretTemplateName="kpack-k8s-basic-auth-git-secret"
            local secretFile=/tmp/$secretTemplateName.tmp
            cp $HOME/binaries/templates/$secretTemplateName.template $secretFile
            extractVariableAndTakeInput $secretFile || returnOrexit || return 1

            printf "Creating k8s secret for git...."
            kubectl apply -f $secretFile -n $namespace && printf "CREATED\n" || printf "FAILED\n"
        else
            sed -i '/K8S_BASIC_SECRET_NAME/d' $HOME/.env
            sleep 1
            printf "\K8S_BASIC_SECRET_NAME=$gitsecretname\n" >> $HOME/.env
            sleep 1
        fi
    fi



    printf "\n\n${greencolor}Configuring service account for kpack...${normalcolor}\n"
    local saname=''
    if [[ $configureType == 'default' ]]
    then
        sed -i '/K8S_SERVICE_ACCOUNT_NAME/d' $HOME/.env
        sleep 1
        printf "\nK8S_SERVICE_ACCOUNT_NAME=kpack-default-sa\n" >> $HOME/.env
        sleep 1
        printf "Setting sa name: kpack-default-sa\n"
        printf "Checking sa: $saname in $namespace..."
        isexist=$(kubectl describe sa $saname -n $namespace)
        if [[ -z $isexist ]]
        then
            saname='new'
        else
            saname='kpack-default-sa'
        fi
    fi
    while [[ -z $saname ]]; do
        read -p "Type the name of existing Service Account in $namespace (type 'new' to create new)? " saname
        if [[ -z $saname ]]
        then
            printf "Empty value not allowed.\n"
        elif [[ $saname != 'new' ]]
        then
            printf "Checking sa: $saname in $namespace..."
            isexist=$(kubectl describe sa $saname -n $namespace)
            if [[ -z $isexist ]]
            then
                saname=''
                printf "${yellowcolor}Secret: $saname not found in namespace: $namespace ${normalcolor}\n"
            fi
        fi
    done
    if [[ $sname == 'new' ]]
    then
        export $(cat $HOME/.env | xargs)
        sleep 1
        printf "User input k8s service account....\n"
        local saTemplateName="kpack-k8s-service-account"
        local saFile=/tmp/$saTemplateName.tmp
        cp $HOME/binaries/templates/$saTemplateName.template $saFile
        extractVariableAndTakeInput $saFile || returnOrexit || return 1
        confirmed=''
        while true; do
            read -p "Would you like to add more secrets (eg: git-secret) to this service account? [y/n] " yn
            case $yn in
                [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                * ) echo "Please answer y or n.";
            esac
        done  
        if [[ $confirmed == 'y' ]]
        then
            local secretTemplateName="kpack-k8s-service-account-secrets"
            local secretFile=/tmp/$secretTemplateName.tmp
            cp $HOME/binaries/templates/$secretTemplateName.template $secretFile
            extractVariableAndTakeInput $secretFile || returnOrexit || return 1
            cat $secretFile >> $saFile
            rm $secretFile
        fi
        printf "Creating k8s service account in namespace: $namespace...."
        kubectl apply -f $saFile -n $namespace && printf "CREATED\n" || printf "FAILED\n"
    fi
    printf "\n\n${greencolor}COMPLETED${normalcolor}\n"
}






function startKpackConfiguration () {

    local configureType=$1 #optional. pass merlin-built-in configure type, eg: 'default'
    

    if [[ $configureType == 'custom' ]]
    then
        configureType=''
    fi

    printf "\n\nconfiguring k8s (secret, serviceaccount) for kpack....\n\n"
    configureK8sSecretAndServiceAccount

    local dynamicName=''

    if [[ -n $configureType ]]
    then
        printf "\nconfiguring $configureType kpack\n"
        sleep 2
        createKpackClusterStack $configureType
        createKpackClusterStore $configureType
        createKpackBuilder "clusterbuilder" $configureType
        dynamicName="KPACK_CLUSTERBUILDER_NAME"
    else
        printf "\nconfiguring kpack based on userinput\n"
        sleep 2
        printf "\n\nconfiguring clusterstack....\n\n"
        sleep 1
        sed -i '/KPACK_CLUSTERSTACK_NAME/d' $HOME/.env
        confirmed=''
        while true; do
            read -p "Would you like configure clusterstack? [y/n] " yn
            case $yn in
                [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                * ) echo "Please answer y or n.";
            esac
        done
        if [[ $confirmed == 'y' ]]
        then
            createKpackClusterStack
        fi

        printf "\n\nconfiguring clusterstore....\n\n"
        sleep 1
        sed -i '/KPACK_CLUSTERSTORE_NAME/d' $HOME/.env

        local confirmed=''
        while true; do
            read -p "Would you like configure clusterstore? [y/n] " yn
            case $yn in
                [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                * ) echo "Please answer y or n.";
            esac
        done
        if [[ $confirmed == 'y' ]]
        then
            createKpackClusterStore
        fi


        printf "\n\nconfiguring kpack builder....\n\n"
        sleep 1
        
        local builderTypeX=''
        printf "what type of builder would you like to create?\n"
        local options=("clusterbuilder" "builder")
        selectFromAvailableOptions ${options[@]}
        local ret=$?
        if [[ $ret == 255 ]]
        then
            printf "${redcolor}No selection were made.${normalcolor}\n"
        else
            # selected option
            builderTypeX=${options[$ret]}
        fi
        if [[ -n $builderTypeX ]]
        then
            dynamicName="KPACK_CLUSTERBUILDER_NAME"
            if [[ $builderTypeX == 'builder' ]]
            then
                dynamicName="KPACK_BUILDER_NAME"
            fi
            sed -i '/'$dynamicName'/d' $HOME/.env
            createKpackBuilder $builderTypeX
        fi
    fi   



    printf "\n\ncleanup..."
    sed -i '/KPACK_CLUSTERSTORE_NAME/d' $HOME/.env
    sleep 1
    sed -i '/KPACK_CLUSTERSTACK_NAME/d' $HOME/.env
    sleep 1
    if [[ -n $dynamicName ]]
    then
        sed -i '/'$dynamicName'/d' $HOME/.env
        sleep 1
    fi
    printf "DONE\n"
}


function startConfigureKpack () {

    printf "${yellowcolor}Select what type of kpack configuration you would like to do?${normalcolor}\n"
    local options=("default" "custom")
    selectFromAvailableOptions ${options[@]}
    local ret=$?
    if [[ $ret == 255 ]]
    then
        printf "${redcolor}No selection were made.${normalcolor}\n"
    else
        startKpackConfiguration ${options[$ret]}
        
    fi
}