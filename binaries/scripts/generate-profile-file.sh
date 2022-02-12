#!/bin/bash
export $(cat /root/.env | xargs)

templateFilesDIR=$(echo "$HOME/binaries/templates" | xargs)


source $HOME/binaries/scripts/contains-element.sh
source $HOME/binaries/scripts/build-profile-file.sh
source $HOME/binaries/scripts/extract-and-take-input.sh

generateProfile () {
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


    extractVariableAndTakeInput $tmpProfileFile
    printf "\nprofile value adjustment...COMPLETE\n"

    printf "\nadding file for confirmation..."
    cp $tmpProfileFile ~/tapconfigs/ && printf "COMPLETE" || printf "FAILED"

    printf "\n\nGenerated profile file: $HOME/tapconfigs/profile-$profilename.yaml\n\n"

    echo "$HOME/tapconfigs/profile-$profilename.yaml" >> $(echo $notifyfile)
}

# generateProfile

# debug

# profilename="debug"
# profiletype="full"
# printf "\ncreating temporary file for profile...."
# tmpProfileFile=$(echo "/tmp/profile-$profilename.yaml" | xargs)
# cp $templateFilesDIR/profile-$profiletype.template $tmpProfileFile && printf "ok." || printf "failed"
# printf "\n"
# buildProfileFile $tmpProfileFile
# end debug