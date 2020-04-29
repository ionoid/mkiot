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

# https://github.com/jasperes/bash-yaml
parse_yaml() {
        local yaml_file=$1
        local prefix=$2
        local s
        local w
        local fs

        s='[[:space:]]*'
        w='[a-zA-Z0-9_.-]*'
        fs="$(echo @|tr @ '\034')"

        (
                sed -e '/- [^\“]'"[^\']"'.*: /s|\([ ]*\)- \([[:space:]]*\)|\1-\'$'\n''  \1\2|g' |

                sed -ne '/^--/s|--||g; s|\"|\\\"|g; s/[[:space:]]*$//g;' \
                        -e "/#.*[\"\']/!s| #.*||g; /^#/s|#.*||g;" \
                        -e "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
                        -e "s|^\($s\)\($w\)${s}[:-]$s\(.*\)$s\$|\1$fs\2$fs\3|p" |

                awk -F"$fs" '{
                        indent = length($1)/2;
                        if (length($2) == 0) { conj[indent]="+";} else {conj[indent]="";}
                        vname[indent] = $2;
                        for (i in vname) {if (i > indent) {delete vname[i]}}
                        if (length($3) > 0) {
                        vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
                        printf("%s%s%s%s=(\"%s\")\n", "'"$prefix"'",vn, $2, conj[indent-1],$3);
                        }
                }' |

                sed -e 's/_=/+=/g' |

                awk 'BEGIN {
                        FS="=";
                        OFS="="
                }
                /(-|\.).*=/ {
                        gsub("-|\\.", "_", $1)
                }
                { print }'
        ) < "$yaml_file"
}

load_buildspec() {
        local yaml_file="$1"
        local prefix="$2"
        eval "$(parse_yaml "$yaml_file" "$prefix")"
}

get_yaml_value() {
        local file="$1"
        local var="$2"

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
        local from=""
        shift

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

        cp -dfR --preserve=all "$src" "$ROOTFS/$dst"
}

RUN() {
	PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' \
                "$CHROOT_CONTAINER" -D "$ROOTFS" "$@"
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
        else
                RUN "$@"
        fi
}
