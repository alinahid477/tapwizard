#!/bin/bash
export $(cat $HOME/.env | xargs)

source $HOME/binaries/scripts/returnOrexit.sh
source $HOME/binaries/scripts/color-file.sh

source $HOME/binaries/tapscripts/build-carto-values-file.sh


function createCartoTemplates () {

    local cartoDir=$HOME/configs/carto
    buildCartoValuesFile "templates" $cartoDir "/tmp/cartoValuesFilePath"

    if [[ ! -f /tmp/cartoValuesFilePath ]]
    then
        returnOrexit || return 1
    fi

    local cartoValuesFile=$(cat /tmp/cartoValuesFilePath)
    if [[ -z $cartoValuesFile || ! -f $cartoValuesFile ]]
    then
        printf "\n${redcolor}Error: carto values file not found. ${normalcolor}\n"
        returnOrexit || return 1
    fi
    mkdir /tmp/carto
    local isexist=$(cat $cartoValuesFile | yq -e '.src' --no-colors)
    if [[ -n $isexist && $isexist != null ]]
    then
        cp $HOME/binaries/templates/carto-clustersource.template /tmp/carto/carto-clustersource.yaml && ytt -f $cartoValuesFile -f /tmp/carto/carto-clustersource.yaml > $cartoDir/carto-clustersource.yaml
    fi
    local isexist=$(cat $cartoValuesFile | yq -e '.test' --no-colors)
    if [[ -n $isexist && $isexist != null ]]
    then
        cp $HOME/binaries/templates/carto-test.template /tmp/carto/carto-test.yaml && ytt -f $cartoValuesFile -f /tmp/carto/carto-test.yaml > $cartoDir/carto-test.yaml
    fi
    local isexist=$(cat $cartoValuesFile | yq -e '.kpack' --no-colors)
    if [[ -n $isexist && $isexist != null ]]
    then
        cp $HOME/binaries/templates/carto-clusterimage-kpack.template /tmp/carto/carto-clusterimage-kpack.yaml && ytt -f $cartoValuesFile -f /tmp/carto/carto-clusterimage-kpack.yaml > $cartoDir/carto-clusterimage-kpack.yaml
    fi
    local isexist=$(cat $cartoValuesFile | yq -e '.knative' --no-colors)
    if [[ -n $isexist && $isexist != null ]]
    then
        cp $HOME/binaries/templates/carto-knative-configmap.template /tmp/carto/carto-knative-configmap.yaml && ytt -f $cartoValuesFile -f /tmp/carto/carto-knative-configmap.yaml > $cartoDir/carto-knative-configmap.yaml
    fi
    local isexist=$(cat $cartoValuesFile | yq -e '.gitwriter' --no-colors)
    if [[ -n $isexist && $isexist != null ]]
    then
        cp $HOME/binaries/templates/carto-gitwriter.template /tmp/carto/carto-gitwriter.yaml && ytt -f $cartoValuesFile -f /tmp/carto/carto-gitwriter.template > $cartoDir/carto-gitwriter.yaml
    fi
    printf "\nfile generation complete...\n"
    local confirmed=''
    while true; do
        read -p "Review and confirm to apply then in the connected k8s cluster: [y/n] " yn
        case $yn in
            [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
            [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
            * ) echo "Please answer y or n.";
        esac
    done    
    if [[ $confirmed == 'y' ]]
    then
        local isexist=$(cat $cartoValuesFile | yq -e '.src' --no-colors)
        if [[ -n $isexist && $isexist != null ]]
        then
            kubectl create -f $cartoDir/carto-clustersource.yaml
        fi
        local isexist=$(cat $cartoValuesFile | yq -e '.test' --no-colors)
        if [[ -n $isexist && $isexist != null ]]
        then
            kubectl create -f $cartoDir/carto-test.yaml
        fi
        local isexist=$(cat $cartoValuesFile | yq -e '.kpack' --no-colors)
        if [[ -n $isexist && $isexist != null ]]
        then
            kubectl create -f $cartoDir/carto-clusterimage-kpack.yaml
        fi
        local isexist=$(cat $cartoValuesFile | yq -e '.knative' --no-colors)
        if [[ -n $isexist && $isexist != null ]]
        then
            kubectl create -f $cartoDir/carto-knative-configmap.yaml
        fi
        local isexist=$(cat $cartoValuesFile | yq -e '.gitwriter' --no-colors)
        if [[ -n $isexist && $isexist != null ]]
        then
            kubectl create -f $cartoDir/carto-gitwriter.yaml
        fi
        printf "\n${greencolor}Carto CRDs created...COMPLETED${normalcolor}\n"
    fi
    printf "Cleaing..."
    rm -r /tmp/carto/ && printf "DONE" || printf "FAILED"
    printf "\n"
}