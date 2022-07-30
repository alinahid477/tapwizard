#!/bin/bash
export $(cat $HOME/.env | xargs)

source $HOME/binaries/scripts/returnOrexit.sh
source $HOME/binaries/scripts/color-file.sh
source $HOME/binaries/scripts/create-secrets.sh

source $HOME/binaries/tapscripts/build-carto-values-file.sh
source $HOME/binaries/tapscripts/build-carto-supplychain-file.sh
source $HOME/binaries/scripts/extract-and-take-input.sh


function resolveServiceAccountClusterRolesAndBindings () {
    local cartoValuesFile=$1 # REQUIRED
    local cartoRBAC=$2 #REQUIRED -- file. eg: $HOME/binaries/templates/carto-rbac.yaml

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

    local clusterRoleName=$(yq 'select(di == 1)' $cartoRBAC | yq -e '.metadata.name')

    printf "Checking ClusterRole: $clusterRoleName..."
    isexist=$(kubectl describe clusterrole $clusterRoleName)
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
    
    printf "\nThis wizard implements few cartographer processes using TektonTask.\n"
    sleep 2
    
    printf "Looking for tekton-controller in ns: tekton-pipeline..."
    local isexist=$(kubectl get pods -n tekton-pipelines | grep -i tekton-pipelines-controller)
    if [[ -z $isexist ]]
    then
        printf "NOT FOUND. Installing tekton...\n"
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
    else
        printf "FOUND.\n"
    fi
    sleep 1    
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
        read -p "Would you like create tekton-task for writing to git (needed for git-ops)? [y/n] " yn
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

function resolveTektonTaskForGrypeScanning () {
    local confirmed=''
    while true; do
        printf "\nGrype TektonTask is needed for source or image scanning. Only one is enough to be used by both CartoSourceScanner and CartoImagerScanner templates. Hence, if you have already created one before no need to create again.\n"
        read -p "Would you like create tekton-task for grype scanner? [y/n] " yn
        case $yn in
            [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
            [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
            * ) echo "Please answer y or n.";
        esac
    done    
    if [[ $confirmed == 'y' ]]
    then
        printf "Creating TektonTask: for source or image scanning...\n"
        local templateFile=$HOME/binaries/templates/carto-scanner.tekton-task.grype.template
        local baseFile=$HOME/configs/carto/carto-scanner.tekton-task.grype.yaml
        cp $templateFile $baseFile
        extractVariableAndTakeInputUsingCustomPromptsFile "prompts-for-variables.carto.json" $baseFile
        kubectl create -f $baseFile
        printf "\nTektonTask create...COMPLETE\n"
        sleep 2
    fi
}

function resolveTektonTaskForTrivyScanning () {
    local confirmed=''
    while true; do
        printf "\nTrivy TektonTask is needed for source or image scanning. Only one is enough to be used by both CartoSourceScanner and CartoImagerScanner templates. Hence, if you have already created one before no need to create again.\n"
        read -p "Would you like create tekton-task for trivy scanner? [y/n] " yn
        case $yn in
            [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
            [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
            * ) echo "Please answer y or n.";
        esac
    done    
    if [[ $confirmed == 'y' ]]
    then
        printf "Creating TektonTask: for source or image scanning...\n"
        local templateFile=$HOME/binaries/templates/carto-scanner.tekton-task.trivy.template
        local baseFile=$HOME/configs/carto/carto-scanner.tekton-task.trivy.yaml
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
    local isTektonGrypeRequired='n'
    local isTektonTrivyRequired='n'
    local isGitSSHRequired='n'
    local isKPackServiceAccountCheck='n'
    local isCreateGitSecret='n'

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

    resolveServiceAccountClusterRolesAndBindings $cartoValuesFile $HOME/binaries/templates/carto-rbac.yaml

    mkdir -p /tmp/carto
    local isexist=''

    isexist=$(cat $cartoValuesFile | yq -e '.src' --no-colors)
    if [[ -n $isexist && $isexist != null ]]
    then
        cp $HOME/binaries/templates/carto-clustersource.template /tmp/carto/carto-clustersource.yaml && ytt --ignore-unknown-comments -f $cartoValuesFile -f /tmp/carto/carto-clustersource.yaml > $cartoDir/carto-clustersource.yaml
        isCreateGitSecret='y'
    fi
    isexist=$(cat $cartoValuesFile | yq -e '.test' --no-colors)
    if [[ -n $isexist && $isexist != null ]]
    then
        isTektonRequired='y'
        isTektonTestRequired='y'
        cp $HOME/binaries/templates/carto-test.template /tmp/carto/carto-test.yaml && ytt --ignore-unknown-comments -f $cartoValuesFile -f /tmp/carto/carto-test.yaml > $cartoDir/carto-test.yaml
    fi
    isexist=$(cat $cartoValuesFile | yq -e '.image_grype' --no-colors)
    if [[ -n $isexist && $isexist != null ]]
    then
        isTektonRequired='y'
        isTektonGrypeRequired='y'
        cp $HOME/binaries/templates/carto-scanner.image-grype.template /tmp/carto/carto-scanner.image-grype.yaml && ytt --ignore-unknown-comments -f $cartoValuesFile -f /tmp/carto/carto-scanner.image-grype.yaml > $cartoDir/carto-scanner.image-grype.yaml
    fi
    isexist=$(cat $cartoValuesFile | yq -e '.image_trivy' --no-colors)
    if [[ -n $isexist && $isexist != null ]]
    then
        isTektonRequired='y'
        isTektonTrivyRequired='y'
        cp $HOME/binaries/templates/carto-scanner.image-trivy.template /tmp/carto/carto-scanner.image-trivy.yaml && ytt --ignore-unknown-comments -f $cartoValuesFile -f /tmp/carto/carto-scanner.image-trivy.yaml > $cartoDir/carto-scanner.image-trivy.yaml
    fi
    isexist=$(cat $cartoValuesFile | yq -e '.source_grype' --no-colors)
    if [[ -n $isexist && $isexist != null ]]
    then
        isTektonRequired='y'
        isTektonGrypeRequired='y'
        cp $HOME/binaries/templates/carto-scanner.source-grype.template /tmp/carto/carto-scanner.source-grype.yaml && ytt --ignore-unknown-comments -f $cartoValuesFile -f /tmp/carto/carto-scanner.source-grype.yaml > $cartoDir/carto-scanner.source-grype.yaml
    fi
    isexist=$(cat $cartoValuesFile | yq -e '.kpack' --no-colors)
    if [[ -n $isexist && $isexist != null ]]
    then
        cp $HOME/binaries/templates/carto-clusterimage-kpack.template /tmp/carto/carto-clusterimage-kpack.yaml && ytt --ignore-unknown-comments -f $cartoValuesFile -f /tmp/carto/carto-clusterimage-kpack.yaml > $cartoDir/carto-clusterimage-kpack.yaml
        isKPackServiceAccountCheck='y'
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
        isGitSSHRequired='y'
        cp $HOME/binaries/templates/carto-gitwriter.template /tmp/carto/carto-gitwriter.yaml && ytt --ignore-unknown-comments -f $cartoValuesFile -f /tmp/carto/carto-gitwriter.yaml > $cartoDir/carto-gitwriter.yaml
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
        isexist=$(cat $cartoValuesFile | yq -e '.source_grype' --no-colors)
        if [[ -n $isexist && $isexist != null ]]
        then
            kubectl create -f $cartoDir/carto-scanner.source-grype.yaml
        fi
        isexist=$(cat $cartoValuesFile | yq -e '.kpack' --no-colors)
        if [[ -n $isexist && $isexist != null ]]
        then
            kubectl create -f $cartoDir/carto-clusterimage-kpack.yaml
        fi
        isexist=$(cat $cartoValuesFile | yq -e '.image_grype' --no-colors)
        if [[ -n $isexist && $isexist != null ]]
        then
            kubectl create -f $cartoDir/carto-scanner.image-grype.yaml
        fi
        isexist=$(cat $cartoValuesFile | yq -e '.image_trivy' --no-colors)
        if [[ -n $isexist && $isexist != null ]]
        then
            kubectl create -f $cartoDir/carto-scanner.image-trivy.yaml
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

    if [[ $isGitSSHRequired == 'y' ]]
    then
        local serviceAccountNamespace=$(cat $cartoValuesFile | yq -e '.service_account.namespace' --no-colors)
        createGitSSHSecret $serviceAccountNamespace
    fi
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
    if [[ $isTektonGrypeRequired == 'y' ]]
    then
        resolveTektonTaskForGrypeScanning
        printf "cleaning env...\n"
        sleep 1
        sed -i '/CARTO_GRYPE_TEKTON_TASK_TYPE/d' $HOME/.env
        sed -i '/CARTO_GRYPE_TEKTON_TASK_NAME/d' $HOME/.env
        sleep 1
        printf "Cleanup .env...COMPLETE"

        printf "Reloading env variable to check for secret requirements...\n"
        export $(cat $HOME/.env | xargs)
        sleep 1
        if [[ -n $CARTO_GRYPE_REGISTRY_SECRET_NAME ]]
        then
            confirmed=''
            while true; do
                read -p "Would you like to create k8s secret: $CARTO_GRYPE_REGISTRY_SECRET_NAME for image registry? [y/n] " yn
                case $yn in
                    [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                    [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                    * ) echo "Please answer y or n.";
                esac
            done    
            if [[ $confirmed == 'y' ]]
            then
                export DOCKER_REGISTRY_SECRET_NAME=$CARTO_GRYPE_REGISTRY_SECRET_NAME
                createDockerRegistrySecret
                unset DOCKER_REGISTRY_SECRET_NAME
            fi
        fi
    fi

    if [[ $isTektonTrivyRequired == 'y' ]]
    then
        resolveTektonTaskForTrivyScanning
        printf "cleaning env...\n"
        sleep 1
        sed -i '/CARTO_TRIVY_TEKTON_TASK_TYPE/d' $HOME/.env
        sed -i '/CARTO_TRIVY_TEKTON_TASK_NAME/d' $HOME/.env
        sleep 1
        printf "Cleanup .env...COMPLETE"

        printf "Reloading env variable to check for secret requirements...\n"
        export $(cat $HOME/.env | xargs)
        sleep 1
        if [[ -n $CARTO_TRIVY_REGISTRY_SECRET_NAME ]]
        then
            confirmed=''
            while true; do
                read -p "Would you like to create k8s secret: $CARTO_TRIVY_REGISTRY_SECRET_NAME for image registry? [y/n] " yn
                case $yn in
                    [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                    [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                    * ) echo "Please answer y or n.";
                esac
            done    
            if [[ $confirmed == 'y' ]]
            then
                export DOCKER_REGISTRY_SECRET_NAME=$CARTO_TRIVY_REGISTRY_SECRET_NAME
                createDockerRegistrySecret
                unset DOCKER_REGISTRY_SECRET_NAME
            fi
        fi
    fi
    
    if [[ $isCreateGitSecret == 'y' ]]
    then
        printf "Reloading env variable to check for Git secrets...\n"
        export $(cat $HOME/.env | xargs)
        sleep 1
        if [[ -n $CARTO_GIT_SECRET_NAME ]]
        then
            confirmed=''
            while true; do
                read -p "Would you like to create k8s secret: CARTO_GIT_SECRET_NAME=$CARTO_GIT_SECRET_NAME for your Git repository? [y/n] " yn
                case $yn in
                    [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                    [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                    * ) echo "Please answer y or n.";
                esac
            done    
            if [[ $confirmed == 'y' ]]
            then
                export K8S_BASIC_SECRET_NAME=$CARTO_GIT_SECRET_NAME
                cretaBasicAuthSecret $HOME/configs
                unset K8S_BASIC_SECRET_NAME
            fi
        fi
    fi

    if [[ $isKPackServiceAccountCheck == 'y' ]]
    then
        printf "Reloading env variable to check for Kpack Service Account...\n"
        export $(cat $HOME/.env | xargs)
        sleep 1
        confirmed=''
        while true; do
            read -p "Would you like to create k8s secret for image registry (to associate with service account)? [y/n] " yn
            case $yn in
                [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                * ) echo "Please answer y or n.";
            esac
        done    
        if [[ $confirmed == 'y' ]]
        then
            createDockerRegistrySecret
        fi

        if [[ -n $CARTO_IMAGE_KPACK_SERVICE_ACCOUNT ]]
        then
            confirmed=''
            while true; do
                read -p "Would you like to create service account:$CARTO_IMAGE_KPACK_SERVICE_ACCOUNT in namespace: default? [y/n] " yn
                case $yn in
                    [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                    [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                    * ) echo "Please answer y or n.";
                esac
            done    
            if [[ $confirmed == 'y' ]]
            then
                export K8S_SERVICE_ACCOUNT_NAME=$CARTO_IMAGE_KPACK_SERVICE_ACCOUNT
                createServiceAccount $HOME/configs
                unset K8S_SERVICE_ACCOUNT_NAME
            fi
        fi
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


function createDeliveryBasic () {

    printf "\n\n\nCreating Carto Basic Delivery...\n\n"

    local filename=''
    while [[ -z $filename ]]; do
        read -p "Type the carto delivery values file name: " filename
        if [[ -z $filename ]]
        then
            printf "Empty value not allowed.\n"
        fi
    done

    mkdir -p $HOME/configs/carto
    mkdir -p /tmp/carto
    local templatedBaseFile="$HOME/binaries/templates/carto-delivery-values.template"
    local baseFile="$HOME/configs/carto/values.delivery.$filename.yaml"

    cp $templatedBaseFile $baseFile

    extractVariableAndTakeInputUsingCustomPromptsFile "prompts-for-variables.delivery.json" $baseFile

    resolveServiceAccountClusterRolesAndBindings $baseFile $HOME/binaries/templates/carto-delivery-rbac.yaml

    cp $HOME/binaries/templates/carto-delivery.basic.template /tmp/carto/carto-delivery.basic.yaml && ytt --ignore-unknown-comments -f $baseFile -f /tmp/carto/carto-delivery.basic.yaml > $HOME/configs/carto/carto-delivery.basic.$filename.yaml

    kubectl apply -f $HOME/configs/carto/carto-delivery.basic.$filename.yaml

    printf "\nCreating Carto Basic Delivery...COMPLETE\n\n"
}