#!/bin/bash

export $(cat $HOME/.env | xargs)

source $HOME/binaries/scripts/extract-and-take-input.sh
source $HOME/binaries/scripts/color-file.sh



function createKpackClusterStore () {
    
    printf "\n\n**** Creating ClusterStore *****\n\n"

    local clusterstoreTemplateName='kapp-clusterstore'
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
    local issuccessful='n'
    mv $clusterstoreFile $HOME/tapconfigs/$clusterstoreTemplateName-$KPACK_CLUSTERSTORE_NAME.yaml && clusterstoreFile=$clusterstoreTemplateName-$KPACK_CLUSTERSTORE_NAME.yaml && printf "SAVED\n" && issuccessful='y'
    if [[ $issuccessful == 'y' ]]
    then
        printf "please review $clusterstoreFile\n"
        local confirmed=''
        while true; do
            read -p "Would you like to install clusterstore: $KPACK_CLUSTERSTORE_NAME now? [y/n] " yn
            case $yn in
                [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                * ) echo "Please answer y or n.";
            esac
        done
        if [[ $confirmed == 'y' ]]
        then
            # kubectl apply -f $clusterstoreFile 
        elif [[ $confirmed == 'n' ]]
        then
            printf "file is saved ($clusterstoreFile). But will not be applied.\n"
        fi
    fi
}



function startConfigureKpack () {

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
}