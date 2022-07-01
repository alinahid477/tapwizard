#!/bin/bash
export $(cat /root/.env | xargs)

source $HOME/binaries/scripts/contains-element.sh
source $HOME/binaries/scripts/keyvaluefile-functions.sh

# read what to prompt for user input from a json file.
buildProfileFile () {
    local templateFilesDIR=$(echo "$HOME/binaries/templates" | xargs)
    local promptsForFilesJSON='prompts-for-files.json'
    local bluecolor=$(tput setaf 4)
    local normalcolor=$(tput sgr0)

    baseProfileFile=$1

    excluded_packages_STR=''

    # iterate over array in json file (json file starts with array)
    # base64 decode is needed so that jq format is per line. Otherwise gettting value from the formatted item object becomes impossible 
    for promptItem in $(jq -r '.[] | @base64' $templateFilesDIR/$promptsForFilesJSON); do
        _jq() {
            echo ${promptItem} | base64 --decode | jq -r ${1}
        }


        # if there's a condition for display this block then first check if condition is met or not
        local conditionalvalue=$(echo $(_jq '.conditionalvalue'))
        local ret=255
        if [[ -n $conditionalvalue && $conditionalvalue != null ]]
        then
            local returnedValue=$(conditionalValueParser $variableFile ${conditionalvalue[@]})
            if [[ -z $returnedValue ]]
            then
                # condition is false. skip this block as this does not apply. 
                # eg PROFILE_TYPE=full || PROFILE_TYPE=lite
                continue
            fi
        fi

        printf "\n\n"

        local confirmed=''
        promptName=$(echo $(_jq '.name')) # get property value of property called "name" from itemObject (aka array element object)
        prompt=$(echo $(_jq '.prompt'))
        hint=$(echo $(_jq '.hint'))
        
        if [[ -n $hint && $hint != null ]] # so, -n works if variable does not exist or value is empty. the jq is outputing null hence need to check null too.
        then
            printf "$prompt (${bluecolor} hint: $hint ${normalcolor})\n"
        else
            printf "$prompt\n"
        fi
        while true; do
            read -p "please confirm [y/n]: " yn
            case $yn in
                [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                [Nn]* ) printf "You said no.\n"; break;;
                * ) echo "Please answer y or n\n";;
            esac
        done
        if [[ $confirmed == 'y' ]]
        then
            filename=$(echo $(_jq '.filename'))

            optionsJson=$(echo $(_jq '.options'))
            if [[ -n $optionsJson && $optionsJson != null ]]
            then
                unset optionSTR
                unset selectedOption
                
                # read it as array so I can perform containsElement for valid value from user input.
                readarray -t options < <(echo $optionsJson | jq -rc '.[]')
                
                # need to convert into comma separated string just so I can display
                for option in "${options[@]}"; do
                    if [[ -z $optionSTR ]]
                    then
                        optionSTR=$option
                    else
                        optionSTR=$(echo "$optionSTR,$option")
                    fi
                done

                while [[ -z $selectedOption ]]; do
                    printf "possible options for $promptName are: [$optionSTR]\n"
                    read -p "type the appropriate option: " selectedOption

                    # this is why I converted the JsonArray into bash array (as mentioned above)
                    containsElement "${selectedOption}" "${options[@]}"
                    ret=$?
                    if [[ $ret == 1 ]]
                    then
                        unset selectedOption
                        printf "You must input a valid value from the available options.\n"
                    fi
                done

                # when multiple options exists (eg: ootb-supplychain basic or basic-with-testing or basic-with-testing-and-scanning)
                # I have mentioned the filename in the JSON prompt in this format supplychain-$.template
                # AND the physical file exists with name supplychain-basic.template, supplychain-basic-testing.template etc
                # Thus based on the input from user (eg: basic or basic-with-testing or basic-with-testing-and-scanning)
                #   I will dynamically form the filename eg: replace the '$' sign with userinput. 
                #   eg: filename='supplychain-$.template' will become filename='supplychain-basic.template' 
                filename=$(echo $filename | sed 's|\$|'$selectedOption'|g')
            fi

            if [[ -n $filename && $filename != null ]]
            then
                # append the content of the chunked file to the profile file.
                printf "adding configs for $promptName...."
                cat $templateFilesDIR/$filename >> $baseProfileFile && printf "ok." || printf "failed."
                printf "\n\n" >> $baseProfileFile
            fi
            printf "\n"
        else
            # whenever the user select 'n' to installing a component of the profile add them in the excluded packages list
            # otherwise what happens is: the config goes missing (because of this script) but tapprofile still thinks it needs to install it.
            # as a result the package ends up being in reconcile error state
            printf "configs for $promptName....skipped."
            packagename=$(echo $(_jq '.packagename'))            
            if [[ -z $packagename || $packagename == null ]]
            then
                readarray -t packagenames < <(echo $(_jq '.packagenames') | jq -rc '.[]')
                for packagename in "${packagenames[@]}"; do
                    if [[ -z $excluded_packages_STR ]]
                    then
                        excluded_packages_STR="  - $packagename"
                    else
                        excluded_packages_STR="$excluded_packages_STR\n  - $packagename"
                    fi                    
                done
            else
                if [[ -z $excluded_packages_STR ]]
                then
                    excluded_packages_STR="  - $packagename"
                else
                    excluded_packages_STR="$excluded_packages_STR\n  - $packagename"
                fi
            fi
            
            printf "\n"
        fi
    done

    # this is special. This does not align with the above generic logic 
    local exclErr=''
    local exclProfileType=$PROFILE_TYPE
    if [[ -z $exclProfileType ]]
    then
        exclProfileType='full'
    fi
    local exclFilename="excluded_packages-$exclProfileType.template"
    local exclReplace='<EXCLUDED-PACKAGES-LIST>'
    printf "\n"
    printf "Adding excluded_packages...."
    sleep 2
    cp $templateFilesDIR/$exclFilename /tmp/ || exclErr='failed'
    if [[ -n $exclErr ]]
    then
        printf "FAILED.\n"
        returnOrexit || return 1
    fi
    awk -v old="${exclReplace}" -v new="${excluded_packages_STR}" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' /tmp/$exclFilename > /tmp/$exclFilename.tmp || exclErr='failed'
    # sed -i 's|'$replace'|'$excluded_packages_STR'|' /tmp/$filename
    if [[ -n $exclErr ]]
    then
        printf "FAILED.\n"
        returnOrexit || return 1
    fi
    cat /tmp/$exclFilename.tmp >> $baseProfileFile || exclErr="failed"
    if [[ -n $exclErr ]]
    then
        printf "FAILED.\n"
        returnOrexit || return 1
    fi
    printf "\n\n" >> $baseProfileFile
    printf "\n"
}