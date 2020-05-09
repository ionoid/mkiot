#!/bin/bash

set -e

ionoid_bootstrap="$(basename "$0")"

. ${mkiot_path}/mkimage/build-helpers.bash

if [ -z "$BASE_IMAGE" ]; then
        fatal "ionoid bootstrap failed 'BASE_IMAGE' not set"
fi

if [ -z "$BASE_IMAGE_MIRROR" ]; then
        fatal "ionoid bootstrap failed 'BASE_IMAGE_MIRROR' not set"
fi

URL="${BASE_IMAGE_MIRROR}${BASE_IMAGE}"

rm -fr image.tar
wget -O ${BASE_DIRECTORY}/image.tar "$URL"

cpwd=$(pwd)
cd $(realpath ${BASE_DIRECTORY})

tar -xf image.tar -C $ROOTFS
rm -fr image.tar

cd $cpwd
