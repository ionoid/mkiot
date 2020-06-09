#!/bin/bash

# Copyright (C) 2020 Open Devices GmbH
# Copyright (C) 2020 Harouni Djalal <tixxdz@opendevices.io>

mkiot="mkiot"
export mkiot_path="$(dirname "$(readlink -f "$BASH_SOURCE")")"

set -e

if [ "$(id -u)" -ne "0" ]; then
        echo "Error: must be root"
        exit 1
fi

if [ ! -r "${mkiot_path}/build-helpers.bash" ] ; then
        export mkiot_path="/usr/lib/mkiot/mkimage/"
fi

if [ ! -r "${mkiot_path}/build-helpers.bash" ] ; then
        >&2 echo "Error: failed to load '${mkiot_path}/build-helpers.bash'"
        exit 1
fi

. ${mkiot_path}/build-helpers.bash

usage() {
	echo >&2 "usage: $mkiot build buildspec.yaml"
	echo >&2 "   ie: $mkiot build examples/scratch/buildspec.yaml"
	echo >&2 "   ie: $mkiot build examples/devtools/debian/buster/devtools-spec.armhf.yaml"
	echo >&2 "       $mkiot build buildspec.yaml"
	exit 1
}

user=$SUDO_USER

optTemp=$(getopt --options 'a:h' --longoptions 'arch:,compression:,no-compression,help' --name "$mkimg" -- "$@")
eval set -- "$optTemp"
unset optTemp

ARCH=
BASE_IMAGE_RELEASE=
BASE_IMAGE=
BUILDSPEC=
ARTIFACTS_COMPRESSION="tar"
ARTIFACTS_NAME=
REMOVE_PREVIOUS="false"
while true; do
	case "$1" in
                -a | --arch)
                        ARCH="$2"
                        shift 2
                        ;;
		--compression)
			ARTIFACTS_COMPRESSION="$2"
			shift 2
			;;
		--no-compression)
			ARTIFACTS_COMPRESSION="none"
			shift 1
			;;
		-h | --help) usage ;;
		--)
			shift
			break
			;;
	esac
done

if [ $# -eq 0 ]; then
        error "operation was not specified"
        usage
fi

OPERATION="$1"
shift

if [ "$OPERATION" == "build" ]; then
        if [ -z "$1" ]; then
                error "'build' operation: 'buidspec yaml file' was not passed"
                usage
        fi
        BUILDSPEC="$1"
        shift
        if [ ! -f "$BUILDSPEC" ]; then
                error "could not find buildspec file: '$BUILDSPEC'"
                usage
        fi
else
        error "operation not supported"
        usage
fi

check_program pip \
        "\tDebian/Ubuntu: package python-pip - A tool for installing and managing Python packages" \
"\n\tError: install python-pip"

check_program update-binfmts \
        "\tDebian/Ubuntu: package binfmt-support - Support for extra binary formats" \
"\n\tError: install binfmt-support"

check_program yq \
        "\tPython: Command-line YAML/XML processor" \
"\n\tError: install with: pip install yq"

check_program systemd-nspawn \
        "\tDebian/Ubuntu: package systemd-container - systemd container/nspawn tools" \
"\n\tError: install systemd-continer"

check_program debootstrap \
        "\tDebian/Ubuntu: package debootstrap - Bootstrap a basic Debian system" \
"\n\tError: install debootstrap"

if [ -z "$ARCH" ]; then
        ARCH=$(get_yaml_value "$BUILDSPEC" "arch")
fi

export BUILD_DIRECTORY=$(get_yaml_value "$BUILDSPEC" "\"build-directory\"")
if [ -z "$BUILD_DIRECTORY" ] || [ "$BUILD_DIRECTORY" == "null" ]; then
        info "'build-directory' of build output not set, using './mkiot-output/'"
        export BUILD_DIRECTORY="mkiot-output/"
fi

if [ -z "$ARCH" ] || [ "$ARCH" == "null" ]; then
        fatal "'arch' architecture is not set"
fi

if [ $# -gt 0 ]; then
        BASE_IMAGE="$1"
        shift
fi

if [ -z "$BASE_IMAGE" ]; then
        BASE_IMAGE=$(get_yaml_value "$BUILDSPEC" $(printf %s "phases.installs | .[0].image"))
fi

if [ -z "$BASE_IMAGE" ] || [ "$BASE_IMAGE" == "null" ]; then
        error "image was not set"
        usage
fi

QEMU_ARCH=$(parse_arch_to_qemu_static $ARCH)

check_program qemu-$QEMU_ARCH-static \
        "\tDebian/Ubuntu: package qemu - fast processor emulator, dummy package\n \
\tDebian/Ubuntu: package qemu-user-static - QEMU user mode emulation binaries (static version)" \
"\n\tError: install qemu qemu-user-static"

export QEMU_ARCH_INTERPRETER=$(check_binfmt_qemu_arch $QEMU_ARCH)

if [ ! -f $QEMU_ARCH_INTERPRETER ]; then
        fatal "failed to find valid a $QEMU_ARCH_INTERPRETER interpreter for $ARCH"
fi

echo
export IMAGES_CACHE=$(get_yaml_value "$BUILDSPEC" "cache.images | .[0]")
if [ -z "$IMAGES_CACHE" ] || [ "$IMAGES_CACHE" == "null" ]; then
        export IMAGES_CACHE="/var/lib/mkiot/images/cache/"
        info "Cache for images not set, using: $IMAGES_CACHE"

        # Create anyway
        mkdir -p "${IMAGES_CACHE}"
        chmod 700 "${IMAGES_CACHE}"
        cache_size="$(du -sh ${IMAGES_CACHE})"
        info "Cache size usage: ${cache_size}"

        info "Cache cleaning images older than 60 days"

        /usr/bin/find -P "${IMAGES_CACHE}" -xdev -depth -mtime +30 -delete
else
        export IMAGES_CACHE=$(realpath $IMAGES_CACHE)
        # Create anyway
        mkdir -p "${IMAGES_CACHE}"
        chmod 700 "${IMAGES_CACHE}"
fi

if [ ! -d $IMAGES_CACHE ]; then
        fatal "Cache '$IMAGES_CACHE' directory check failed"
fi

cache_size="$(du -sh ${IMAGES_CACHE})"
info "Cache size usage: ${cache_size}"

export CHROOT_CONTAINER=$(which systemd-nspawn)

time="$(date +%F_%H%M%S)"

setup_slave_mount() {
        self_inode=$(stat -L -c "%i" /proc/self/ns/mnt)
        pid1_inode=$(stat -L -c "%i" /proc/1/ns/mnt)

        # Unshare -m failed ?
        if [ "$self_inode" == "$pid1_inode" ]; then
                fatal "Working on host mount namespace is not allowed"
        fi

        # Lets propagate slave mode
        mount --make-rslave /
}

run_commands() {
        # update ROOTFS here
        export ROOTFS="$1"
        local phase="$2"
        local idx="$3"

        # Make sure of working space
        check_rootfs_inode

        # Run commands
        "${mkiot_path}/buildspec-run.py" --rootfs="$ROOTFS" \
                --buildspec="$BUILDSPEC" --phase="${phase}, $idx"
}

run_phases_installs() {
        local idx="$1"
        shift 1
        local build_args="$@"

        if [ "$BASE_IMAGE" == "debian" ] || [ "$BASE_IMAGE" == "scratch" ]; then
                # Set default release mirror values
                . ${mkiot_path}/$BASE_IMAGE/install
                export BASE_IMAGE_RELEASE="${release}"
                export BASE_IMAGE_MIRROR="${mirror}"
        fi

        if [ -z "$BASE_IMAGE" ]; then
                fatal "'phases.installs[$idx].image or base image is not set in buildspec and no default value"
        fi

        local l_release=$(get_yaml_value "$BUILDSPEC" "$(printf %s "phases.installs | .[$idx].release")")
        if [ "$l_release" != "null" ]; then
                # Use default release
                export BASE_IMAGE_RELEASE="${l_release}"
        fi

        local l_mirror=$(get_yaml_value "$BUILDSPEC" "$(printf %s "phases.installs | .[$idx].mirror")")
        if [ "$l_mirror" != "null" ]; then
                # Use default mirror
                export BASE_IMAGE_MIRROR="${l_mirror}"
        fi

        if [ -z "$BASE_IMAGE_MIRROR" ]; then
                fatal "'phases.installs[$idx].mirror' for image '$BASE_IMAGE' is not set in buildspec and no default value"
        fi

        mkdir -p ${BUILD_DIRECTORY}
        chown ${user}.${user} ${BUILD_DIRECTORY}

        export INSTALLS_NAME=$(get_yaml_value "$BUILDSPEC" "$(printf %s "phases.installs | .[$idx].name")")
        if [ -z "$INSTALLS_NAME" ]; then
                export INSTALLS_NAME="install-$idx-output-$time"
        fi

        local install_args=$(get_yaml_value "$BUILDSPEC" "$(printf %s "phases.installs | .[$idx][\"install-args\"]")")
        if [ "$install_args" == "null" ]; then
                # clear them up
                install_args=""
        fi

        info "phases.installs[$idx] parent image '$BASE_IMAGE' into 'image=${BUILD_DIRECTORY}/${INSTALLS_NAME}'"

        local reuse="false"
        local saveincache="false"
        local cache=$(get_yaml_value "$BUILDSPEC" "$(printf %s "phases.installs | .[$idx].cache")")
        if [ -z "$cache" ] || [ "$cache" == "null" ]; then
                info "removing image '${BUILD_DIRECTORY}/${INSTALLS_NAME}', \
                        set 'cache: \"reuse\" to reuse old images"
                rm -fr -- "${BUILD_DIRECTORY}/${INSTALLS_NAME}"
        elif [[ "$cache" == *"reuse"* ]]; then
                reuse="true"
                if [ -d "${IMAGES_CACHE}/${INSTALLS_NAME}" ]; then
                        rm -fr -- "${BUILD_DIRECTORY}/${INSTALLS_NAME}"
                        info "Cache found image install at '${IMAGES_CACHE}/${INSTALLS_NAME}'"
                        info "Copying image from cache to '${BUILD_DIRECTORY}/${INSTALLS_NAME}'"
                        cp -dfRT --preserve=all "${IMAGES_CACHE}/${INSTALLS_NAME}" "${BUILD_DIRECTORY}/${INSTALLS_NAME}/"
                        chown ${user}.${user} "${BUILD_DIRECTORY}/${INSTALLS_NAME}"
                else
                        # Image was not found so lets recreate it
                        reuse="false"
                fi
        else
                fatal "Cache check value '$cache' not supported on image ${INSTALLS_NAME}'"
        fi

        if [ "$reuse" == "false" ]; then
                local builddir="$(mktemp -d ${BUILD_DIRECTORY}/${INSTALLS_NAME}.XXXXXXXXXXX.tmp)"
                export ROOTFS="$builddir"

                # Make sure of working space
                check_rootfs_inode

                (
	                set -x
	                mkdir -p "$ROOTFS"
                )

                mkdir -p ${ROOTFS}
                chown ${user}.${user} ${ROOTFS}

                info "Building with: 'buildspec=$BUILDSPEC' phases.installs[$idx] 'arch=$ARCH' 'image=$BASE_IMAGE' 'release=$BASE_IMAGE_RELEASE' \
'build-directory=$BUILD_DIRECTORY' 'name=$INSTALLS_NAME' 'install-args=${install_args} ${build_args}'"

                if [[ "$BASE_IMAGE_MIRROR" == *"ionoid"* ]]; then
                        "${mkiot_path}/ionoid-bootstrap.bash" --arch="$ARCH" "$install_args" "$build_args"
                elif [ "$BASE_IMAGE" == "scratch" ]; then
                        "${mkiot_path}/ionoid-bootstrap.bash"
                elif [ "$BASE_IMAGE" == "debian" ]; then
                        # pass all remaining arguments to $script
                        "${mkiot_path}/debootstrap" --arch="$ARCH" "$install_args" "$build_args"
                else
                        fatal "unsupported target image '$BASE_IMAGE'"
                fi
        
                #
                # Make sure to point back rootfs to INSTALLS_NAME,
                # it will be picked later by next phases and also treat
                # target as a file
                #
                rm -fr -- "${BUILD_DIRECTORY}/${INSTALLS_NAME}"
                mv -fT "$ROOTFS" "${BUILD_DIRECTORY}/${INSTALLS_NAME}"

        else
                info "Reusing image: phases.installs[$idx] 'arch=$ARCH' 'image=$BASE_IMAGE' 'release=$BASE_IMAGE_RELEASE' \
'build-directory=$BUILD_DIRECTORY' 'name=$INSTALLS_NAME' 'install-args=${install_args} ${build_args}'"
                if [ ! -d "${BUILD_DIRECTORY}/${INSTALLS_NAME}" ]; then
                        fatal "Image '${BUILD_DIRECTORY}/${INSTALLS_NAME} not found!"
                fi
        fi

        # Lets run commands from the installs phase
        run_commands "${BUILD_DIRECTORY}/${INSTALLS_NAME}" "installs" "$idx"

        info "phases.installs[$idx] finished, image location: ${BUILD_DIRECTORY}/${INSTALLS_NAME}"

        if [[ "$cache" == *"save"* ]]; then
                info "Cache saving 'image=${BUILD_DIRECTORY}/${INSTALLS_NAME}' into cache ${IMAGES_CACHE}"
                cp -dfRT --preserve=all "${BUILD_DIRECTORY}/${INSTALLS_NAME}" "${IMAGES_CACHE}/${INSTALLS_NAME}.tmp/"
                rm -fr -- "${IMAGES_CACHE}/${INSTALLS_NAME}"
                mv -fT "${IMAGES_CACHE}/${INSTALLS_NAME}.tmp" "${IMAGES_CACHE}/${INSTALLS_NAME}"
                chown root.root "${IMAGES_CACHE}/${INSTALLS_NAME}"
                chown root.root "${IMAGES_CACHE}"
                # make sure that cache permission are always saved
                chmod 700 "${IMAGES_CACHE}"
        fi

        echo
}

run_phases_pre_builds() {
        local idx="$1"
        local use_image="$2"
        shift 2

        if [ -z $use_image ]; then
                # Lets use last INSTALLS_NAME
                use_image=$INSTALLS_NAME
        fi

        info "phases.pre-builds[$idx] started on 'image=${BUILD_DIRECTORY}/${use_image}'"

        run_commands "${BUILD_DIRECTORY}/${use_image}" "pre-builds" "$idx"

        info "phases.pre-builds[$idx] finished, image location: ${BUILD_DIRECTORY}/${use_image}"
        echo
}

run_phases_builds() {
        local idx="$1"
        local use_image="$2"
        shift 2

        if [ -z $use_image ]; then
                # Lets use last INSTALLS_NAME
                use_image=$INSTALLS_NAME
        fi

        info "phases.builds[$idx] started on 'image=${BUILD_DIRECTORY}/${use_image}'"

        run_commands "${BUILD_DIRECTORY}/${use_image}" "builds" "$idx"

        info "phases.builds[$idx] finished, image location: ${BUILD_DIRECTORY}/${use_image}"
        echo
}

run_phases_post_builds() {
        local idx="$1"
        local use_image="$2"
        shift 2

        if [ -z $use_image ]; then
                # Lets use last INSTALLS_NAME
                use_image=$INSTALLS_NAME
        fi

        info "phases.post-builds[$idx] started on 'image=${BUILD_DIRECTORY}/${use_image}'"

        run_commands "${BUILD_DIRECTORY}/${use_image}" "post-builds" "$idx"

        info "phases.post-builds[$idx] finished, image location: ${BUILD_DIRECTORY}/${use_image}"
        echo
}

compress_artifact() {
        local dir="$1"
        local compression="$2"
        local file="$3"
        local target="$3"

        if [ -z "$compression" ] || [ "$compression" == "none" ]; then
                compression="tar"
        fi

        cdir=$(pwd)
        cd $dir

        if [ "$compression" == "zip" ]; then
                file="${file}.zip"
                zip_artifact "$file" "$target"
        else
                file="${file}.${compression}"
                tar_artifact "$file" "$target"
        fi

        # fix up permissions
        chown ${user}.${user} "${file}"

        cd $cdir

        info "Generated artifact in: '${dir}/${file}'"
}

generate_artifact() {
        local idx="$1"
        local ARTIFACTS_USE="$2"
        local ARTIFACTS_BUILD_DIRECTORY="$BUILD_DIRECTORY/artifacts/"

        mkdir -p ${ARTIFACTS_BUILD_DIRECTORY}
        chown ${user}.${user} ${ARTIFACTS_BUILD_DIRECTORY}

        local ARTIFACTS_NAME=$(get_yaml_value "$BUILDSPEC" "$(printf %s "artifacts | .[$idx].name")")
        if [ -z "$ARTIFACTS_NAME" ] || [ "$ARTIFACTS_NAME" == "null" ]; then
                ARTIFACTS_NAME="${ARTIFACTS_USE}"
        fi

        (
                set -e
                ARTIFACTS_NAME="$(echo -n "$ARTIFACTS_NAME")"
        )

        local suffix=$(get_yaml_value "$BUILDSPEC" "$(printf %s "artifacts | .[$idx].suffix")")
        if [ "$suffix" != "null" ]; then
                suffix="$(eval "$suffix")"
                ARTIFACTS_NAME="$ARTIFACTS_NAME-$suffix"
        fi

        info "Generating artifact '$ARTIFACTS_NAME'"

        # Setup final artifact base directory

        local artifact="${ARTIFACTS_NAME}"
        rm -fr "${ARTIFACTS_BUILD_DIRECTORY}/${artifact}"

        info "Generating artifact '$ARTIFACTS_NAME' copying 'use=${ARTIFACTS_USE}' into 'name=${ARTIFACTS_BUILD_DIRECTORY}/${artifact}'"
        # Make sure to treat target as file
        cp -dfRT --preserve=all "${BUILD_DIRECTORY}/${ARTIFACTS_USE}" "${ARTIFACTS_BUILD_DIRECTORY}/${artifact}"

        info "Running artifact '${ARTIFACTS_BUILD_DIRECTORY}/${artifact}' commands"
        run_commands "${ARTIFACTS_BUILD_DIRECTORY}/${artifact}" "artifacts" "$idx"

        info "Copying artifact files and directories into '${ARTIFACTS_BUILD_DIRECTORY}/${artifact}'"
        for i in {0..20}
        do
                local file=$(get_yaml_value "$BUILDSPEC" "$(printf %s "artifacts | .[$idx].files[$i]")")
                if [ "$file" == "null" ]; then
                        break
                fi

                if [ -d "${BUILD_DIRECTORY}/${file}" ]; then
                        cp -dfR --preserve=all "${BUILD_DIRECTORY}/${file}/." "${ARTIFACTS_BUILD_DIRECTORY}/${artifact}"
                elif [ -f "${BUILD_DIRECTORY}/${file}" ]; then
                        cp -df --preserve=all "${BUILD_DIRECTORY}/${file}" "${ARTIFACTS_BUILD_DIRECTORY}/${artifact}"
                else
                        error "failed to add '${BUILD_DIRECTORY}/${file}' to artifact '${artifact}' not supported"
                fi
        done

        local compression=$(get_yaml_value "$BUILDSPEC" "$(printf %s "artifacts | .[$idx].compression")")

        compress_artifact "${ARTIFACTS_BUILD_DIRECTORY}" "${compression}" "${artifact}"

        rm -fr "${ARTIFACTS_BUILD_DIRECTORY}/${artifact}"
}

ENV_VARS_PARMS=""
buildspecenvs=$(get_yaml_value "$BUILDSPEC" "$(printf %s "env.variables")")
if [ "$buildspecenvs" != "null" ]; then
        for i in {0..20}
        do
                entry=$(get_yaml_key_value "$BUILDSPEC" "env.variables" "$i" "=")
                if [ "$entry" == "null" ]; then
                        break
                fi

                if [ ! -n "${ENV_VARS_PARMS}" ]; then
                        ENV_VARS_PARMS="--setenv="${entry}""
                else
                        ENV_VARS_PARMS="${ENV_VARS_PARMS} --setenv="${entry}""
                fi
        done

        export ENV_VARS_PARMS="${ENV_VARS_PARMS}"
fi


# Lets setup and propagate slave mode
setup_slave_mount


## Lets start first phase "installs"
echo
info "Running phases installs"
for i in {0..4}
do
        export BASE_IMAGE=$(get_yaml_value "$BUILDSPEC" "$(printf %s "phases.installs | .[$i].image")")
        if [ "$BASE_IMAGE" == "null" ]; then
                break
        elif [ -z "$BASE_IMAGE" ]; then
                fatal "image was not set"
        fi

        run_phases_installs "$i" "$@"
        BASE_IMAGE="null"
done

## Lets run "pre-builds"
echo
info "Running phases pre-builds"
for i in {0..4}
do
        USE_IMAGE=$(get_yaml_value "$BUILDSPEC" "$(printf %s "phases[\"pre-builds\"] | .[$i].use")")
        if [ "$USE_IMAGE" == "null" ]; then
                break
        fi

        run_phases_pre_builds "$i" "$USE_IMAGE"
        USE_IMAGE="null"
done

## Run "builds"
echo
info "Running phases builds"
for i in {0..4}
do
        USE_IMAGE=$(get_yaml_value "$BUILDSPEC" "$(printf %s "phases.builds | .[$i].use")")
        if [ "$USE_IMAGE" == "null" ]; then
                break
        fi

        run_phases_builds "$i" "$USE_IMAGE"
        USE_IMAGE="null"
done

## Run "post-builds"
echo
info "Running phases post-builds"
for i in {0..4}
do
        USE_IMAGE=$(get_yaml_value "$BUILDSPEC" "$(printf %s "phases[\"post-builds\"] | .[$i].use")")
        if [ "$USE_IMAGE" == "null" ]; then
                break
        fi

        run_phases_post_builds "$i" "$USE_IMAGE"
        USE_IMAGE="null"
done

## Last stage generate artifact
echo
info "Generating artifacts"
for i in {0..4}
do
        artifacts_use=$(get_yaml_value "$BUILDSPEC" "$(printf %s "artifacts | .[$i].use")")
        if [ -z "$artifacts_use" ] || [ "$artifacts_use" == "null" ]; then
                break
        fi

        generate_artifact "$i" "$artifacts_use"
        artifacts_use="null"
done

echo
# Lets display cache size again
cache_size="$(du -sh ${IMAGES_CACHE})"
info "Cache size usage: ${cache_size}"

exit 0
