#!/bin/bash

set -xe

ionoid_bootstrap="$(basename "$0")"

. ${mkiot_path}/build-helpers.bash

if [ -z "$ROOTFS" ] || [ "$ROOTFS" == "/" ]; then
        fatal "ionoid bootstrap failed 'ROOTFS' invalid value"
fi

# Make sure of working space
check_rootfs_inode

if [ -z "$BASE_IMAGE" ]; then
        fatal "ionoid bootstrap failed 'BASE_IMAGE' not set"
fi

if [ -z "$BASE_IMAGE_MIRROR" ]; then
        fatal "ionoid bootstrap failed 'BASE_IMAGE_MIRROR' not set"
fi

if [ "$BASE_IMAGE" == "scratch" ]; then
        mkdir -p --mode=700 "${ROOTFS}/root"
        mkdir -p --mode=755 "${ROOTFS}/dev" "${ROOTFS}/tmp" "${ROOTFS}/sys" "${ROOTFS}/proc" \
                "$ROOTFS/usr/bin" "$ROOTFS/usr/sbin" "$ROOTFS/etc" "$ROOTFS/home" \
                "$ROOTFS/mnt" "$ROOTFS/opt" "$ROOTFS/run" "$ROOTFS/var/log"
        mkdir -p --mode=755 "$ROOTFS/usr/lib" "$ROOTFS/usr/lib32" \
                "$ROOTFS/usr/lib64" "$ROOTFS/usr/libx32"

        cpwd=$(pwd)
        cd $(realpath "${ROOTFS}")
        ln -sr usr/bin bin
        ln -sr usr/sbin sbin
        ln -sr usr/lib lib
        ln -sr usr/lib32 lib32
        ln -sr usr/lib64 lib64
        ln -sr usr/libx32 libx32

        cd $cpwd
else
        URL="${BASE_IMAGE_MIRROR}/${BASE_IMAGE}"

        check_url $URL

        cpwd=$(pwd)
        cd $(realpath "${BASE_DIRECTORY}")

        tmpfile="$(mktemp "image-download-$(date +%Y-%m-%d).XXXXXXXXXX").tar"
        info "Downloading '${URL} into ${BASE_DIRECTORY}/${tmpfile}'"
        wget -O "${tmpfile}" "${URL}"

        tar -xf "${tmpfile}" -C "${ROOTFS}"
        rm -fr "${tmpfile}"

        cd $cpwd
fi
