#!/bin/bash
IFS=''
private_registry='registry.cn-shanghai.aliyuncs.com'
private_repo='rainbow954'
workdir=/home/ryan/git/csi-driver-nfs/sealos
ver=v4.6.0
project=csi-driver-nfs

function build_sealos_image() {
    cd $1
    deal_manifest_folder $1
    echo "sealos build -t $private_registry/$private_repo/$project:$ver-sealos   -f Kubefile  ."
    sudo sealos build -t $private_registry/$private_repo/$project:$ver-sealos -f Kubefile .
    echo "sealos push $private_registry/$private_repo/$project:$ver-sealos"
    sudo sealos push $private_registry/$private_repo/$project:$ver-sealos
}

function deal_manifest_folder() {
    for file in $1/*; do
        if [[ -f "$file" ]]; then
            file_type=$(file "$file" | grep yaml)
            if [[ $file_type =~ yaml ]]; then
                read_manifest_parse $file
            fi

        elif [[ -d "$file" ]]; then
            deal_manifest_folder $file
        fi
    done
}

function read_manifest_parse() {
    filename=$1
    # read content line by line
    cat $filename | while read -r OLINE || [[ -n ${OLINE} ]]; do
        LINE=$(echo "$OLINE" | sed 's/^[ ]*//g')
        #echo ${LINE}
        # if line is start with 'image:'
        if [ "$(echo "$LINE" | grep "image:")" != "" ]; then
            imageValue=$(echo "$LINE" | awk -F " " '{print $2}')
            #echo $imageValue
            dealImage $imageValue
        fi
    done
}

#can do any aciton with related image
function dealImage() {
    image=$1
    imageNameTag=$(echo ${image##*/})
    imageTag=$(echo ${imageNameTag##*:})
    imageName=$(echo ${imageNameTag%:*})
    imageRepoUrl=''
    imageRepo=''
    if [[ $image == */* ]]; then
        imageRepoUrl=$(echo ${image%/*})
        imageRepo=$(echo ${imageRepoUrl##*/})
    fi

    if [ "$imageRepo" != "" ] && [ "$imageRepo" != "$imageName" ]; then
        imageNameTag="$imageRepo-$imageName:$imageTag"
    fi
    # echo $imageNameTag
    echo 'docker pull '$image
    #sudo docker pull $image

    echo "docker tag  $image $private_registry/$private_repo/$imageNameTag"
    #sudo docker tag $image $private_registry/$private_repo/$imageNameTag

    echo "docker push   $private_registry/$private_repo/$imageNameTag"
    #sudo docker push $private_registry/$private_repo/$imageNameTag

    # mkdir -p  $workdir/images/shim/
    #  if [[ ! -f "$workdir/images/shim/${project}ImageList" ]]; then
    #     touch $workdir/images/shim/${project}ImageList
    #  fi
    # exist_inImageList=$(cat $workdir/images/shim/${project}ImageList | grep "docker-daemon:$image")
    # if [[ $exist_inImageList == "" ]]; then
    #     echo "docker-daemon:$image" >>$workdir/images/shim/${project}ImageList
    # fi

    mkdir -p $workdir/images/skopeo/
    echo "docker save -o $workdir/images/'$imageName-$imageTag'.tar ' $image"
    sudo docker save -o $workdir/images/skopeo/$imageName-$imageTag.tar $image
    tarimage=$imageName:$imageTag
    if [ "$imageRepo" != "" ]; then
        tarimage=$imageRepo/$tarimage
    fi
    if [[ ! -f "$workdir/images/skopeo/tar.txt" ]]; then
        touch $workdir/images/skopeo/tar.txt
    fi
    exist_intar=$(cat $workdir/images/skopeo/tar.txt | grep "docker-archive:$imageName-$imageTag.tar@$tarimage")
    if [[ $exist_intar == "" ]]; then
        echo "docker-archive:$imageName-$imageTag.tar@$tarimage" >>$workdir/images/skopeo/tar.txt
    fi

}

convertImageRepoUrl() {
    # echo $1
    image=$1
    registry=$2

    imageName=$(echo ${image##*/})
    imageRepoUrl=$(echo ${image%/*})
    imageRepo=$(echo ${imageRepoUrl##*/})

    if [ "$imageRepo" != "$imageName" ]; then
        imageName="$imageRepo-$imageName"
    fi
    imageRepoUrl="$private_registry/$private_repo/$imageName"
    if [ "$registry" != "" ]; then
        imageRepoUrl="$private_repo/$imageName"
    fi

    echo $imageRepoUrl
    return $?
}

build_sealos_image $workdir
