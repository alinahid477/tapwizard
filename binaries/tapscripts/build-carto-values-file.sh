#!/bin/bash
export $(cat $HOME/.env | xargs)

source $HOME/binaries/scripts/returnOrexit.sh
source $HOME/binaries/scripts/color-file.sh

source $HOME/binaries/scripts/assemble-file.sh
source $HOME/binaries/scripts/extract-and-take-input.sh

function buildCartoValuesFile () {
    local valuesType=$1 # REQUIRED. Possible Values: templates, supply-chain
    local cartoDir=$2 # REQUIRED. the directory where carto files will be created
    local outputLocation=$3 # REQUIRED. A file containing the location/path of the generated values file. eg: file /tmp/vlocation containing this line "~/configs/carto/values.templates.yaml"

    if [[ -z $valuesType || -z $outputLocation ]]
    then
        printf "\n${redcolor}Error: no values type is supplied to generate or output location is missing.${normalcolor}\n"
        returnOrexit || return 1
    fi

    printf "\n\n\nGenerating carto values of type $valuesType file\n\n"

    local promptsForFilesJSON="prompts-for-files.carto-$valuesType.json"
    local templatedBaseFile="$HOME/binaries/templates/carto-values-base-$valuesType.template"
    local baseFile="$cartoDir/values.$valuesType.yaml"

    local isexist=''
    mkdir -p $cartoDir && cp $templatedBaseFile $baseFile && isexist='y'

    if [[ $isexist != 'y' ]]
    then
        printf "\n${redcolor}Error: Directory or File creation failed.${normalcolor}\n"
        returnOrexit || return 1
    fi

    printf "\n\nAssembling file...\n\n"
    assembleFile $promptsForFilesJSON $baseFile
    printf "\nvalues file of type $valuesType assembly...COMPLETE\n"

    printf "\n\nPopulating $baseFile with user input...\n\n"
    extractVariableAndTakeInputUsingCustomPromptsFile "prompts-for-variables.carto.json" $baseFile
    printf "\nFile $baseFile generation...COMPLETE\n"

    echo $baseFile > $outputLocation
}