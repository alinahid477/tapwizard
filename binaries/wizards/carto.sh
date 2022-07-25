#!/bin/bash
export $(cat $HOME/.env | xargs)

source $HOME/binaries/scripts/returnOrexit.sh
source $HOME/binaries/scripts/color-file.sh

source $HOME/binaries/tapscripts/build-carto-values-file.sh
source $HOME/binaries/tapscripts/build-carto-supplychain-file.sh
source $HOME/binaries/scripts/extract-and-take-input.sh


function resolveServiceAccountClusterRolesAndBindings () {
    local cartoValuesFile=$1 # REQUIRED
    local cartoRBAC=$HOME/binaries/templates/carto-rbac.yaml

    printf "\nStarting ClusterRole and ClusterBinding configuring...\n"

    if [[ ! -f $cartoValuesFile ]]
    then
        printf "\n${redcolor}Error: CartoValuesFile is needed for fulfilling pre-requisite of clusterrole and clusterrolebinding.${normalcolor}\n"
    fi
    local serviceAccountName=$(cat $cartoValuesFile | yq -e '.service_account.name' --no-colors)
    local serviceAccountNamespace=$(cat $cartoValuesFile | yq -e '.service_account.namespace' --no-colors)
    if [[ -z $serviceAccountName || -z $serviceAccountNamespace ]]
    then
        printf "\n${redcolor}Error: ValuesFile does not container service account name or its namespace.${normalcolor}\n"
        returnOrexit || return 1
    fi

    printf "Checking SA: $serviceAccountName..."
    local isexist=$(kubectl describe sa $serviceAccountName -n $serviceAccountNamespace)
    if [[ -z $isexist ]]
    then
        printf "NOT FOUND. Creating new...\n"
        export K8S_SERVICE_ACCOUNT_NAME=$serviceAccountName
        printf "User input k8s service account....\n"
        local saTemplateName="k8s-service-account"
        local saFile=$HOME/configs/$saTemplateName.$serviceAccountName.yaml
        cp $HOME/binaries/templates/$saTemplateName.template $saFile
        extractVariableAndTakeInput $saFile || returnOrexit || return 1
        local confirmed=''
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
            local secretTemplateName="k8s-service-account-secrets"
            local secretFile=/tmp/$secretTemplateName.tmp
            cp $HOME/binaries/templates/$secretTemplateName.template $secretFile
            extractVariableAndTakeInput $secretFile || returnOrexit || return 1
            cat $secretFile >> $saFile
            rm $secretFile
        fi
        printf "Creating k8s service account $serviceAccountName in namespace: $namespace...."
        kubectl apply -f $saFile -n $serviceAccountNamespace && printf "CREATED\n" || printf "FAILED\n"

        sleep 2
    else
        printf "FOUND. Continuing...\n"
    fi

    printf "Checking ClusterRole: carto-clusterrole..."
    isexist=$(kubectl describe clusterrole carto-clusterrole)
    if [[ -z $isexist ]]
    then
        printf "NOT FOUND. Creating NEW and binding with sa $serviceAccountName in ns: $serviceAccountNamespace...\n"
        kubectl apply -f <(ytt --ignore-unknown-comments -f $cartoValuesFile -f $cartoRBAC) || returnOrexit || return 1
        printf "CREATED and BOUNDED with sa $serviceAccountName in ns: $serviceAccountNamespace\n"
    else
        printf "FOUND. binding with sa $serviceAccountName in ns: $serviceAccountNamespace...\n"
        kubectl apply -f <(ytt --ignore-unknown-comments -f $cartoValuesFile -f $cartoRBAC) || returnOrexit || return 1
        printf "BOUNDED with sa $serviceAccountName in ns: $serviceAccountNamespace\n"
    fi
}


function resolveTekton () {
    printf "\nStarting Tekton configuration...\n"
    sleep 2
    printf "Looking for ns: tekton-pipelines..."
    sleep 1
    local isexist=$(kubectl get ns | grep -i tekton-pipelines)
    if [[ -z $isexist ]]
    then
        printf "NOT FOUND.\n"
    else
        printf "FOUND.\n"
    fi
    local confirmed=''
    while true; do
        read -p "Would you like to install tekton (needed for test, git-ops operations)? [y/n] " yn
        case $yn in
            [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
            [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
            * ) echo "Please answer y or n.";
        esac
    done    
    if [[ $confirmed == 'y' ]]
    then
        printf "Installing Tekton....\n"
        local TEKTON_VERSION=0.30.0 
        kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/previous/v$TEKTON_VERSION/release.yaml
        printf "\nTekton installation...COMPLETE\n"
        sleep 2
    fi
}

function resolveTektonTaskForTest () {
    local confirmed=''
    while true; do
        read -p "Would you like create tekton-task for maven test (needed for supply-chain with test)? [y/n] " yn
        case $yn in
            [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
            [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
            * ) echo "Please answer y or n.";
        esac
    done    
    if [[ $confirmed == 'y' ]]
    then
        printf "Creating TektonTask: for maven-test for test...\n"
        local templateFile=$HOME/binaries/templates/carto-test.tekton-task.maven.template
        local baseFile=$HOME/configs/carto/carto-test.tekton-task.maven.yaml
        cp $templateFile $baseFile
        extractVariableAndTakeInputUsingCustomPromptsFile "prompts-for-variables.carto.json" $baseFile
        kubectl create -f $baseFile
        printf "\nTektonTask create...COMPLETE\n"
        sleep 2
    fi
}

function resolveTektonTaskForGitWriter () {
    local confirmed=''
    while true; do
        read -p "Would you like to install tekton git-cli task from tekton catalog (needed for git-ops)? [y/n] " yn
        case $yn in
            [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
            [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
            * ) echo "Please answer y or n.";
        esac
    done    
    if [[ $confirmed == 'y' ]]
    then
        printf "Installing Tekton git cli....\n"
        kapp deploy --yes -a tekton-git-cli -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/git-cli/0.2/git-cli.yaml
        printf "\nTekton git cli...COMPLETE\n"
        sleep 2       
    fi
    confirmed=''
    while true; do
        read -p "Would you like create tekton-task for git-writer (needed for git-ops)? [y/n] " yn
        case $yn in
            [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
            [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
            * ) echo "Please answer y or n.";
        esac
    done    
    if [[ $confirmed == 'y' ]]
    then
        printf "Creating TektonTask: for git-writer for git-ops...\n"
        local templateFile=$HOME/binaries/templates/carto-gitwriter.tekton-task.configwriter.template
        local baseFile=$HOME/configs/carto/carto-gitwriter.tekton-task.configwriter.yaml
        cp $templateFile $baseFile
        extractVariableAndTakeInputUsingCustomPromptsFile "prompts-for-variables.carto.json" $baseFile
        kubectl create -f $baseFile
        printf "\nTektonTask create...COMPLETE\n"
        sleep 2
    fi
}



function cartoTemplateWizardPrompts () {

    printf "\n\n${yellowcolor}Cartographer Supply Chain templating wizard. It will perform the followings..."
    printf "\n\t 1. Create/Use Service Account, ClusterRole and ClusterRoleBinding (carto supply chain needs appropriate permissions to run)"
    printf "\n\t 2. Create/Use Various cartographer templates. This wizard will walk you through."
    printf "\n\t 3. Install Tekton.dev if needed (This wizard uses tekton task to for creating test, git-ops operation if your supply chain contains test and/or git-ops)"
    printf "\n\t 4. Create tekton task for test if needed (This wizard uses tekton task to for creating test. eg: maven test)"
    printf "\n\t 5. Create tekton task for Git Writer if needed (This wizard uses tekton task for writing configmap to git for git-ops)"
    
    printf "\n${normalcolor}\n\n"

    sleep 2
}

function createCartoTemplates () {
    cartoTemplateWizardPrompts

    local isTektonRequired='n'
    local isTektonTestRequired='n'
    local isTektonGitWriterRequired='n'

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

    resolveServiceAccountClusterRolesAndBindings $cartoValuesFile

    mkdir /tmp/carto
    local isexist=''

    isexist=$(cat $cartoValuesFile | yq -e '.src' --no-colors)
    if [[ -n $isexist && $isexist != null ]]
    then
        cp $HOME/binaries/templates/carto-clustersource.template /tmp/carto/carto-clustersource.yaml && ytt --ignore-unknown-comments -f $cartoValuesFile -f /tmp/carto/carto-clustersource.yaml > $cartoDir/carto-clustersource.yaml
    fi
    isexist=$(cat $cartoValuesFile | yq -e '.test' --no-colors)
    if [[ -n $isexist && $isexist != null ]]
    then
        isTektonRequired='y'
        isTektonTestRequired='y'
        cp $HOME/binaries/templates/carto-test.template /tmp/carto/carto-test.yaml && ytt --ignore-unknown-comments -f $cartoValuesFile -f /tmp/carto/carto-test.yaml > $cartoDir/carto-test.yaml
    fi
    isexist=$(cat $cartoValuesFile | yq -e '.kpack' --no-colors)
    if [[ -n $isexist && $isexist != null ]]
    then
        cp $HOME/binaries/templates/carto-clusterimage-kpack.template /tmp/carto/carto-clusterimage-kpack.yaml && ytt --ignore-unknown-comments -f $cartoValuesFile -f /tmp/carto/carto-clusterimage-kpack.yaml > $cartoDir/carto-clusterimage-kpack.yaml
    fi
    isexist=$(cat $cartoValuesFile | yq -e '.knative' --no-colors)
    if [[ -n $isexist && $isexist != null ]]
    then
        cp $HOME/binaries/templates/carto-knative-configmap.template /tmp/carto/carto-knative-configmap.yaml && ytt --ignore-unknown-comments -f $cartoValuesFile -f /tmp/carto/carto-knative-configmap.yaml > $cartoDir/carto-knative-configmap.yaml
    fi
    isexist=$(cat $cartoValuesFile | yq -e '.gitwriter' --no-colors)
    if [[ -n $isexist && $isexist != null ]]
    then
        isTektonRequired='y'
        isTektonGitWriterRequired='y'
        cp $HOME/binaries/templates/carto-gitwriter.template /tmp/carto/carto-gitwriter.yaml && ytt --ignore-unknown-comments -f $cartoValuesFile -f /tmp/carto/carto-gitwriter.template > $cartoDir/carto-gitwriter.yaml
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
        isexist=$(cat $cartoValuesFile | yq -e '.src' --no-colors)
        if [[ -n $isexist && $isexist != null ]]
        then
            kubectl create -f $cartoDir/carto-clustersource.yaml
        fi
        isexist=$(cat $cartoValuesFile | yq -e '.test' --no-colors)
        if [[ -n $isexist && $isexist != null ]]
        then
            kubectl create -f $cartoDir/carto-test.yaml
        fi
        isexist=$(cat $cartoValuesFile | yq -e '.kpack' --no-colors)
        if [[ -n $isexist && $isexist != null ]]
        then
            kubectl create -f $cartoDir/carto-clusterimage-kpack.yaml
        fi
        isexist=$(cat $cartoValuesFile | yq -e '.knative' --no-colors)
        if [[ -n $isexist && $isexist != null ]]
        then
            kubectl create -f $cartoDir/carto-knative-configmap.yaml
        fi
        isexist=$(cat $cartoValuesFile | yq -e '.gitwriter' --no-colors)
        if [[ -n $isexist && $isexist != null ]]
        then
            kubectl create -f $cartoDir/carto-gitwriter.yaml
        fi
        printf "\n${greencolor}Carto CRDs created...COMPLETED${normalcolor}\n"
    fi

    printf "Cleaing..."
    rm -r /tmp/carto/ && printf "DONE" || printf "FAILED"
    printf "\n"

    if [[ $isTektonRequired == 'y' ]]
    then
        resolveTekton
    fi
    if [[ $isTektonTestRequired == 'y' ]]
    then
        resolveTektonTaskForTest
    fi
    if [[ $isTektonGitWriterRequired == 'y' ]]
    then
        resolveTektonTaskForGitWriter
    fi

    printf "\nCarto Template Wizard...COMPLETE\n"
}

function createSupplyChain () {

    local cartoDir=$HOME/configs/carto
    buildCartoSupplyChainFile $cartoDir "/tmp/cartoSupplyChainFilePath"

    if [[ ! -f /tmp/cartoSupplyChainFilePath ]]
    then
        returnOrexit || return 1
    fi

    local supplychainFile=$(cat /tmp/cartoSupplyChainFilePath)
    if [[ -z $supplychainFile || ! -f $supplychainFile ]]
    then
        printf "\n${redcolor}Error: carto values file not found. ${normalcolor}\n"
        returnOrexit || return 1
    fi

    printf "\nCreating SupplyChain from file: $supplychainFile...\n"
    kubectl apply -f $supplychainFile
}