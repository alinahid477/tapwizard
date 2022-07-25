#!/bin/bash
export $(cat $HOME/.env | xargs)

source $HOME/binaries/scripts/returnOrexit.sh
source $HOME/binaries/scripts/color-file.sh

source $HOME/binaries/scripts/assemble-file.sh
source $HOME/binaries/scripts/extract-and-take-input.sh

function buildCartoSupplyChainFile () {
    local cartoDir=$1 # REQUIRED. the directory where carto files will be created
    local outputLocation=$1 # REQUIRED. A file containing the location/path of the generated values file. eg: file /tmp/vlocation containing this line "~/configs/carto/values.templates.yaml"

    if [[ -z $cartoDir || -z $outputLocation ]]
    then
        printf "\n${redcolor}Error: no values type is supplied to directory or output location is missing.${normalcolor}\n"
        returnOrexit || return 1
    fi
    local filename=''
    while [[ -z $filename ]]; do
        read -p "Type the supplychain file name: " filename
        if [[ -z $filename ]]
        then
            printf "Empty value not allowed.\n"
        fi
    done

    printf "\n\n\nGenerating supplychain file: carto-supplychain.$filename.yaml \n\n"

    local promptsForFilesJSON="prompts-for-files.carto-supplychain.json"
    local templatedBaseFile="$HOME/binaries/templates/carto-supplychain.base.template"
    local baseFile="$cartoDir/carto-supplychain.$filename.yaml"

    if [[ ! -f $templatedBaseFile ]]
    then
        printf "\n${redcolor}Error: $templateBaseFile not found.${normalcolor}\n"
        returnOrexit || return 1
    fi

    local isexist=''
    mkdir -p $cartoDir
    cp $templatedBaseFile $baseFile && isexist='y'

    if [[ $isexist != 'y' ]]
    then
        printf "\n${redcolor}Error: Directory or File creation failed.${normalcolor}\n"
        returnOrexit || return 1
    fi

    printf "\n\nAssembling file...\n\n"
    assembleFile $promptsForFilesJSON $baseFile
    printf "\nvalues file of type $valuesType assembly...COMPLETE\n"


    printf "\n\nPopulating $baseFile with user input...\n\n"
    extractVariableAndTakeInputUsingCustomPromptsFile "prompts-for-variables.supplychain.json" $baseFile
    printf "\nFile $baseFile generation...COMPLETE\n"

    echo $baseFile > $outputLocation
}