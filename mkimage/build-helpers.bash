#!/bin/bash

# Copyright (C) 2020 Open Devices GmbH

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

COPY() {
        shift

        local from=""
        for i in "$@"
        do
                case "$i" in
                        --from=*)
                        from="${i#*=}"
                        shift
                        ;;
                esac
        done

        local src="$1"
        local dst="$2"
        shift 2

        if [ -z "$src" ]; then
                fatal "COPY() source was not set"
        fi

        if [ -z "$dst" ]; then
                fatal "COPY() destination was not set"
        fi

        # Copy from another image build
        if [ -n "$from" ]; then
                src="$BASE_DIRECTORY/$from/$src"
        fi

        cp -dfR --preserve=all "$(realpath $src)" "$ROOTFS/$dst"
}

RUN_SCRIPT() {
        shift

        local from=""
        for i in "$@"
        do
                case "$i" in
                        --from=*)
                        from="${i#*=}"
                        shift
                        ;;
                esac
        done

        local script="$1"
        local dest="$2"

        if [ -z "$script" ]; then
                fatal "SCRIPT() source script was not set"
        fi

        # Copy from another image build
        if [ -n "$from" ]; then
                script="${BASE_DIRECTORY}/${from}/${script}"
        fi

        if [ ! -f "$script" ]; then
                error "SCRIPT() can not find file '$script'"

                # lets try directory of buildspec
                local lp="$(dirname $(realpath ${BUILDSPEC}))"
                script="${lp}/${script}"
        fi

        if [ ! -f "$script" ]; then
                fatal "SCRIPT() can not find file '$script'"
        fi

        if [ ! -x "$script" ]; then
                fatal "SCRIPT() file '$script' is not executable"
        fi

        if [ -z "$dest" ]; then
                # lets force it to be in "/bin/"
                dest="/bin/$(basename ${script})"
        fi

        "$CHROOT_CONTAINER" -D "$ROOTFS" --bind="$(realpath ${script}):${dest}" $ENV_VARS_PARMS "${dest}"

}

RUN() {
        local shell=""
        for i in "$@"
        do
                case "$i" in
                        --shell=*)
                        shell="${i#*=}"
                        shift
                        ;;
                esac
        done

        if [ -n "$shell" ]; then
                "$CHROOT_CONTAINER" -D "$ROOTFS" $ENV_VARS_PARMS "/bin/$shell" "-xc" "$@"
        else
                "$CHROOT_CONTAINER" -D "$ROOTFS" $ENV_VARS_PARMS "$@"
        fi
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

        tar --numeric-owner --create --auto-compress --file "$file" --directory "$target" --transform='s,^./,,' .
}

run_yaml_commands() {
        local cmd="$1"

        if [ "$cmd" == "null" ]; then
                return
        elif [ "$cmd" == "copy" ]; then
                COPY "$@"
        elif [ "$cmd" == "script" ]; then
                RUN_SCRIPT "$@"
        else
                RUN "$@"
        fi
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
