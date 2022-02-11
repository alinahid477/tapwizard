#!/bin/bash
export $(cat /root/.env | xargs)

templateFilesDIR=$(echo "$HOME/binaries/templates" | xargs)
promptsForFilesJSON='prompts-for-files.json'
promptsForVariablesJSON='prompts-for-variables.json'
bluecolor=$(tput setaf 4)
normalcolor=$(tput sgr0)

containsElement () {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 1; done
  return 0
}

# read what to prompt for user input from a json file.
buildProfileFile () {
    baseProfileFile=$1
    # iterate over array in json file (json file starts with array)
    # base64 decode is needed so that jq format is per line. Otherwise gettting value from the formatted item object becomes impossible 
    for promptItem in $(jq -r '.[] | @base64' $templateFilesDIR/$promptsForFilesJSON); do
        printf "\n\n"

        _jq() {
            echo ${promptItem} | base64 --decode | jq -r ${1}
        }
        unset confirmed
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
                    if [[ $ret == 0 ]]
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

            # append the content of the chunked file to the profile file.
            printf "adding configs for $promptName...."
            cat $templateFilesDIR/$filename >> $baseProfileFile && printf "ok." || printf "failed."
            printf "\n\n" >> $baseProfileFile
            printf "\n"
        else
            printf "configs for $promptName....skipped."
            printf "\n"
        fi
    done
}



buildProfile () {
    baseProfileFile=$1
    printf "extract variables from profile file....\n"
    # extract variable from file (variable format is: <NAME-OF-THE-VARIABLE>)
    extracts=($(grep -o '<[A-Za-z0-9_\-]*>' $baseProfileFile))
    keys=()

    # populate keys with unique values only (in the file there may be multiple occurances of same variables)
    i=0
    while [[ $i -lt ${#extracts[*]} ]] ; do
        containsElement "${extracts[$i]}" "${keys[@]}"
        ret=$?
        if [[ $ret == 0 ]]
        then
            keys+=("${extracts[$i]}")
        fi
        ((i=$i+1))
    done


    isinputneeded='n'

    # iterate over each variable name that may need user input (if not exist as environment variable)
    for v in "${keys[@]}"; do
        printf "\n\n"
        # modifying the extracted variable name to valid variable name format 
        # eg: extracted variable name was: <NAME-OF-THE-VARIABLE>. So
        # 1. Modify to remove '<' and '>'
        # 2. Modify to replace '-' with '_'
        # so, <NAME-OF-THE-VARIABLE> is modified to NAME_OF_THE_VARIABLE
        inputvar=$(echo "${v}" | sed 's/[<>]//g' | sed 's/[-]/_/g')
        
        unset inp
        # dynamic variable-->eg: variable name (NAME_OF_THE_VARIABLE) in a variable ('inputvar')
        # the way to access the value dynamic variable is: ${!inputvar}

        # if input variable does not exist as environment variable (meaning if the value is empty or unset that means variable does not exists)
        if [[ -z ${!inputvar} ]]; then 
            # when does not exist prompt user to input value
            hint=$(jq -r '.[] | select(.name == "'$v'") | .hint' $templateFilesDIR/$promptsForVariablesJSON)
            isRecordAsEnvVar=$(jq -r '.[] | select(.name == "'$v'") | .isRecordAsEnvVar' $templateFilesDIR/$promptsForVariablesJSON)
            if [[ -n $hint && $hint != null ]]
            then
                printf "$inputvar Hint: ${bluecolor}$hint ${normalcolor}\n"
            fi
            isinputneeded='y'
            while [[ -z $inp ]]; do
                read -p "input value for $inputvar: " inp
                if [[ -z $inp ]]
                then
                    printf "empty value is not allowed.\n"
                fi
            done
            sed -i 's|'${v}'|'$inp'|g' $baseProfileFile
            # add to .env for later use (eg: during developer namespace creation)
            if [[ -n $isRecordAsEnvVar && $isRecordAsEnvVar == true ]]
            then
                printf "$inputvar=${inp}" >> $HOME/.env
                printf "\n" >> $HOME/.env
            fi
        else
            # when exists as environment variable already, no need to prompt user for input. Just replace in the file.
            inp=${!inputvar} # the value of the environment variable (here accessed as dynamic variable)
            printf "environment variable found: $inputvar=$inp\n"
            sed -i 's|<'$inputvar'>|'$inp'|g' $baseProfileFile
        fi
    done

    if [[ $isinputneeded == 'n' ]]
    then
        printf "\nAll needed values for profile found in environment variable. No user input needed.\n"
    fi

}



printf "\n*******Starting profile wizard*******\n\n"


unset profilename
while [[ -z $profilename ]]; do
    read -p "name of the profile: " profilename
    if [[ -z $profilename ]]
    then
        printf "empty value is not allowed.\n"
    fi
done

unset inp
unset profiletype
while [[ -z $profiletype ]]; do
    read -p "type of the profile [full or lite] (default: full): " inp
    if [[ -z $inp ]]
    then
        inp='full'
    fi
    if [[ $inp == 'full' || $inp == 'lite' ]]
    then
        profiletype=$inp
    fi
    if [[ -z $profiletype ]]
    then
        printf "Please provide a valid value. Only \"full\" or \"lite\" are allowed valid value.\n"
    fi
done

if [[ -n $DESCRIPTOR_NAME ]]
then
    DESCRIPTOR_NAME=$(echo "$DESCRIPTOR_NAME-$profiletype" | xargs)
    printf "\nAdjusted descriptor name DESCRIPTOR_NAME=$DESCRIPTOR_NAME...ok\n"
fi


printf "\ncreating temporary file for profile...."
tmpProfileFile=$(echo "/tmp/profile-$profilename.yaml" | xargs)
cp $templateFilesDIR/profile-$profiletype.template $tmpProfileFile && printf "ok." || printf "failed"
printf "\n"

printf "generate profile file...\n"
buildProfileFile $tmpProfileFile
printf "\nprofile file generation...COMPLETE.\n"


printf "\n\n\n"


buildProfile $tmpProfileFile
printf "\nprofile value adjustment...COMPLETE\n"

printf "\nadding file for confirmation..."
cp $tmpProfileFile ~/tapconfigs/ && printf "COMPLETE" || printf "FAILED"

printf "\n\nGenerated profile file: $HOME/tapconfigs/profile-$profilename.yaml\n\n"

echo "$HOME/tapconfigs/profile-$profilename.yaml" >> $(echo $notifyfile)

