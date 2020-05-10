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

if [ "$BASE_IMAGE" == "scratch" ]; then
        cpwd=$(pwd)
        cd $(realpath "${ROOTFS}")

        mkdir -p --mode=700 "/root"
        mkdir -p --mode=755 "/dev" "/tmp" "/sys" "/proc" "/usr/bin" \
                "/usr/sbin" "/etc" "/home" \
                "/mnt" "/opt" "/run" "/var/log"
        mkdir -p --mode=755 "/usr/lib" "/usr/lib32" "/usr/lib64" "/usr/libx32"

        ln -sr usr/bin bin
        ln -sr usr/sbin sbin
        ln -sr usr/lib lib
        ln -sr usr/lib32 lib32
        ln -sr usr/lib64 lib64
        ln -sr usr/libx32 libx32

        cd $cpwd
else
        URL="${BASE_IMAGE_MIRROR}/${BASE_IMAGE}"

        cpwd=$(pwd)
        cd $(realpath "${BASE_DIRECTORY}")

        tmpfile="$(mktemp "image-download-$(date +%Y-%m-%d).XXXXXXXXXX").tar"
        info "Downloading '${URL} into ${BASE_DIRECTORY}/${tmpfile}'"
        wget -O "${tmpfile}" "${URL}"

        tar -xf "${tmpfile}" -C $ROOTFS
        rm -fr "${tmpfile}"

        cd $cpwd
fi
