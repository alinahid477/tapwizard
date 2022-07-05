name=$1
forcebuild=$2
if [[ $name == "forcebuild" ]]
then
    name=''
    forcebuild='forcebuild'
fi
if [[ -z $name ]]
then
    printf "\nUser did not supply a name. Default container and image name: merlin-tapwizard\n"
    sleep 2
    name='merlin-tapwizard'
fi
isexists=$(docker images | grep "\<$name\>")
if [[ -z $isexists || $forcebuild == "forcebuild" ]]
then
    docker build . -t $name
fi
docker run -it --rm -v ${PWD}:/root/ -v /var/run/docker.sock:/var/run/docker.sock --add-host kubernetes:127.0.0.1 --name $name $name