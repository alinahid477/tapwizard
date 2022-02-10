#!/bin/bash
export $(cat /root/.env | xargs)
containsElement () {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 1; done
  return 0
}

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


cp ~/binaries/profile-$profiletype.template /tmp/profile-$profilename.yaml

extracts=($(grep -o '<[A-Za-z0-9_\-]*>' ~/binaries/profile-$profiletype.template))
keys=()

# populate keys with only unique values
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

printf "\n\n\n***********Profile creator wizard********\n\n"


isinputneeded='n'

for v in "${keys[@]}"; do
    #inputvar=$(echo "${v//<}")
    inputvar=$(echo "${v}" | sed 's/[<>]//g' | sed 's/[-]/_/g')
    
    unset inp
    if [[ -z ${!inputvar} ]]; then 
        isinputneeded='y'
        while [[ -z $inp ]]; do
            read -p "input value for $inputvar: " inp
            if [[ -z $inp ]]
            then
                printf "empty value is not allowed.\n"
            fi
        done
        sed -i 's|'${v}'|'$inp'|g' /tmp/profile-$profilename.yaml
    else
        inp=${!inputvar}
        sed -i 's|<'${inputvar}'>|'$inp'|g' /tmp/profile-$profilename.yaml
    fi    
done

if [[ $isinputneeded == 'n' ]]
then
    printf "\nAll needed values for profile found in environment variable. No user input needed.\n"
fi

cp /tmp/profile-$profilename.yaml ~/tapconfigs/

printf "\n\nProfile wizard generated file in ~/tapconfigs/profile-$profilename.yaml\n\n"

echo "$HOME/tapconfigs/profile-$profilename.yaml" >> $(echo $notifyfile)

