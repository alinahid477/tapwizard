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

    local isexist=$(cat $cartoValuesFile | yq -e '.src' --no-colors)
    if [[ -n $isexist && $isexist != null ]]
    then
        ytt -f $cartoValuesFile -f $HOME/binaries/templates/carto-clustersource.template > $cartoDir/carto-clustersource.yaml
    fi
    local isexist=$(cat $cartoValuesFile | yq -e '.test' --no-colors)
    if [[ -n $isexist && $isexist != null ]]
    then
        ytt -f $cartoValuesFile -f $HOME/binaries/templates/carto-test.template > $cartoDir/carto-test.yaml
    fi
    local isexist=$(cat $cartoValuesFile | yq -e '.kpack' --no-colors)
    if [[ -n $isexist && $isexist != null ]]
    then
        ytt -f $cartoValuesFile -f $HOME/binaries/templates/carto-clusterimage-kpack.template > $cartoDir/carto-clusterimage-kpack.yaml
    fi
    local isexist=$(cat $cartoValuesFile | yq -e '.knative' --no-colors)
    if [[ -n $isexist && $isexist != null ]]
    then
        ytt -f $cartoValuesFile -f $HOME/binaries/templates/carto-knative-configmap.template > $cartoDir/carto-knative-configmap.yaml
    fi
    local isexist=$(cat $cartoValuesFile | yq -e '.gitwriter' --no-colors)
    if [[ -n $isexist && $isexist != null ]]
    then
        ytt -f $cartoValuesFile -f $HOME/binaries/templates/carto-gitwriter.template > $cartoDir/carto-gitwriter.yaml
    fi
}