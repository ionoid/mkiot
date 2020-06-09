#!/bin/bash

# Copyright (C) 2020 Open Devices GmbH

buildspec_run="${mkiot_path}/buildspec-run.py"

info() {
        >&2 echo -e "Info: ${*}"
}

error() {
        >&2 echo -e "Error: ${*}"
}

fatal() {
        >&2 echo -e "Fatal: ${*}, exiting"
        exit 1
}

unmount() {
        local path="$1"
        umount --recursive -n $path
}

check_rootfs_inode() {
        local hostroot="/"
        local buildroot="$ROOTFS"
        realroot_inode=$(stat -L -c "%i" "$hostroot")
        buildroot_inode=$(stat -L -c "%i" "$buildroot")

        if [ "$realroot_inode" == "$buildroot_inode" ]; then
                fatal "rootfs of build point to real host root"
        fi
}

check_program() {
        local program
        local packages
        local path
        local error
        program="${1}"
        packages="${2}"
        error="${3}"

        info "Checking for ${program}"
        info "${packages}"
        path=$(command -v "${program}")

        if [[ "${?}" -ne 0 ]]; then
                fatal "${error}"
        fi

        info    "\tFound at $path"

        echo
}

parse_arch_to_qemu_static() {
        local arch=$1

        if [ -z "$arch" ]; then
                fatal "architecture was not set"
        fi

        if [ "$arch" == "arm" ] || [ "$arch" == "armhf" ] || [ "$arch" == "armel" ]; then
                echo -n "arm"
        fi
}

get_yaml_key_value() {
        local yaml_file="$1"
        local prefix="$2"
        local idx="$3"
        local sep="$4"

        if [ ! -f "$yaml_file" ]; then
                fatal "File buildspec yaml '$yaml_file' can not be found"
        fi

        local key=$(cat "$yaml_file" | yq -r -c ".$prefix" | yq -r "to_entries | .[$idx].key")
        if [ "$key" == "null" ]; then
                echo -n "null"
        else
                local val=$(cat "$yaml_file" | yq -r -c ".$prefix" | yq -r "to_entries | .[$idx].value")
                echo -n "${key}${sep}${val}"
        fi
}

get_yaml_value() {
        local file="$1"
        local var="$2"

        if [ ! -f "$file" ]; then
                fatal "File buildspec yaml '$file' can not be found"
        fi

        echo -n "$(cat "$file" | yq -r -c ".$var")"
}

getuuid() {
        local uuid=$(cat /proc/sys/kernel/random/uuid)
        echo -n $uuid
}

check_binfmt_qemu_arch() {
        local arch="$1"
        local interpreter

        info "Checking for /proc/sys/fs/binfmt_misc/qemu-$arch  for qemu-$arch-static"

        out=$(cat /proc/sys/fs/binfmt_misc/qemu-$arch | grep "qemu-$arch-static" -)

        if [[ "${?}" -ne 0 ]]; then
                fatal "\tfailed to find binfmt_misc qemu-$arch-static"
                exit 1
        fi

        info "\t$out"

        interpreter=(${out// / })
        echo -n ${interpreter[1]}
}


RUN() {
        # Make sure of working space
        check_rootfs_inode

        # Following commands do not need ENV_VARS_PRAMS
        "$buildspec_run" --rootfs="$ROOTFS" "$@"
}

get_base_image_mirror() {
        local image="$1"

        if [ "$image" == "debian" ]; then
                echo -n "http://deb.debian.org/debian/"
        fi
}

get_base_image_release() {
        local image="$1"

        if [ "$image" == "debian" ]; then
                echo -n "stretch"
        fi
}

finalize_etc_config() {
        local rootfs=$1

        mkdir -p "$rootfs/etc"

        # make sure /etc/resolv.conf has something useful in it
        cat > "$ROOTFS/etc/resolv.conf" << 'EOF'
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

}

zip_artifact() {
        fatal "Zip not supported now it will be added soon, please use 'tar'"
}

tar_artifact() {
        local file="$1"
        local target="$2"

        tar --numeric-owner --create --auto-compress \
                --xattrs --xattrs-include=* --file "$file" \
                --directory "$target" --transform='s,^./,,' .
}

check_url() {
        local url="$1"
        if command -v wget; then
                info "Checking url '$url'"
                local ret=$(wget -S --spider $url 2>&1 | grep 'HTTP/1.1 200 OK')
                if [ -z "$ret" ]; then
                        fatal "Check url '$url' failed"
                fi
        else
                fatal "check url failed can not locate 'wget'"
        fi
}
