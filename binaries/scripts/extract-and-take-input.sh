#!/bin/bash


export $(cat /root/.env | xargs)

extractVariableAndTakeInput () {
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
        
        # read hint from pompts variable file and display it
        hint=$(jq -r '.[] | select(.name == "'$v'") | .hint' $templateFilesDIR/$promptsForVariablesJSON)
        if [[ -n $hint && $hint != null ]]
        then
            printf "$inputvar Hint: ${bluecolor}$hint ${normalcolor}\n"
        fi
        
        
        # This may be a flawd logic. Commenting it now. More checks needs to be done.
        # if the above value is true (isRecordAsEnvVar=true) this means that environment it should not exist in .env file yet 
        # AND will be written in when user provide the input. (only reason it is being stored in .env so it can be reused at developer namespaces)
        # so performing the below in case it existed in .env file (the only way this could occur, in error ofcourse, is if the enduser/I use an older .env file)
        # if [[ -n $isRecordAsEnvVar && $isRecordAsEnvVar == true ]]
        # then
        #     sed -i '/'$inputvar'/d' /root/.env
        #     sleep 1
        # fi

        unset inp
        # dynamic variable-->eg: variable name (NAME_OF_THE_VARIABLE) in a variable ('inputvar')
        # the way to access the value dynamic variable is: ${!inputvar}

        # if input variable does not exist as environment variable (meaning if the value is empty or unset that means variable does not exists)
        # Hence, need to prompt user for input and take userinput.
        if [[ -z ${!inputvar} ]]; then 
            # when does not exist prompt user to input value
            isinputneeded='y'
            while [[ -z $inp ]]; do
                read -p "input value for $inputvar: " inp
                if [[ -z $inp ]]
                then
                    printf "empty value is not allowed.\n"
                fi
            done
            sed -i 's|'${v}'|'$inp'|g' $baseProfileFile
            
            # read this property to see if this variable should be recorded in .env file for usage in developer workspace (eg: git-ops-secret)
            isRecordAsEnvVar=$(jq -r '.[] | select(.name == "'$v'") | .isRecordAsEnvVar' $templateFilesDIR/$promptsForVariablesJSON)
            # add to .env for later use if instructed in the prompt file (eg: during developer namespace creation)            
            if [[ -n $isRecordAsEnvVar && $isRecordAsEnvVar == true ]]
            then
                printf "\n" >> $HOME/.env
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