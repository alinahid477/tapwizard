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
    mv $file $HOME/configs/$fileprefix-$KPACK_CLUSTERSTORE_NAME.yaml && file=$HOME/configs/$fileprefix-$filesuffix.yaml && printf "SAVED\n" && issuccessful='y'
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
    
    printf "\n\n**** Creating ClusterStore *****\n\n"

    local clusterstoreTemplateName='kpack-clusterstore'
    local clusterstoreFile=/tmp/$clusterstoreTemplateName.tmp
    cp $HOME/binaries/templates/$clusterstoreTemplateName.template $clusterstoreFile
    extractVariableAndTakeInput $clusterstoreFile || returnOrexit || return 1

    printf "processing file...\n"
    export $(cat $HOME/.env | xargs)
    sleep 1

    printf "saving file..."
    if [[ -z $KPACK_CLUSTERSTORE_NAME ]]
    then
        while [[ -z $KPACK_CLUSTERSTORE_NAME ]]; do
            read -p "input value for $inputvar: " KPACK_CLUSTERSTORE_NAME
            
            if [[ -z $KPACK_CLUSTERSTORE_NAME ]]
            then
                printf "${redcolor}empty value is not allowed.${normalcolor}\n"                
            fi
        done
    fi
    
    saveAndApplyFile "clusterstore" $clusterstoreTemplateName $KPACK_CLUSTERSTORE_NAME $clusterstoreFile
}

function createKpackClusterStack () {
    
    printf "\n\n**** Creating ClusterStack *****\n\n"

    local clusterstackTemplateName='kpack-clusterstack'
    local clusterstackFile=/tmp/$clusterstackTemplateName.tmp
    cp $HOME/binaries/templates/$clusterstackTemplateName.template $clusterstackFile
    extractVariableAndTakeInput $clusterstackFile || returnOrexit || return 1

    printf "processing file...\n"
    export $(cat $HOME/.env | xargs)
    sleep 1

    printf "saving file..."
    if [[ -z $KPACK_CLUSTERSTACK_NAME ]]
    then
        while [[ -z $KPACK_CLUSTERSTACK_NAME ]]; do
            read -p "input value for $inputvar: " KPACK_CLUSTERSTACK_NAME
            
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

    printf "\n\n**** Creating Builder ($builderType) *****\n\n"

    local builderTemplateName="kpack-$builderType"
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


function startConfigureKpack () {

    printf "\n\nconfiguring clusterstack....\n\n"
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

    printf "\n\ncleanup..."
    sed -i '/KPACK_CLUSTERSTORE_NAME/d' $HOME/.env
    sleep 1
    sed -i '/KPACK_CLUSTERSTACK_NAME/d' $HOME/.env
    sleep 1
    printf "DONE\n"


    printf "\n\nconfiguring clusterstack....\n\n"
    sleep 1
    sed -i '/KPACK_CLUSTERSTACK_NAME/d' $HOME/.env
    local confirmed=''
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

    printf "\n\nconfiguring kpack builder....\n\n"
    sleep 1
    
    local builderTypeX=''
    local dynamicName=''
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