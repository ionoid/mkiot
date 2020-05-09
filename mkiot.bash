#!/bin/bash

# Copyright (C) 2020 Open Devices GmbH
# Copyright (C) 2020 Harouni Djalal <tixxdz@opendevices.io>

mkiot="$(basename "$0")"
export mkiot_path="$(dirname "$(readlink -f "$BASH_SOURCE")")"

set -e

if [ ! -r "${mkiot_path}/mkimage/build-helpers.bash" ] ; then
        export mkiot_path="/usr/lib/mkiot/"
fi

if [ ! -r "${mkiot_path}/mkimage/build-helpers.bash" ] ; then
        >&2 echo "Error: failed to load '${mkiot_path}/mkimage/build-helpers.bash'"
        exit 1
fi

. ${mkiot_path}/mkimage/build-helpers.bash

usage() {
	echo >&2 "usage: $mkiot [-f buildspec.yaml] [-a arch] [-t tag] image [install-args]"
	echo >&2 "   ie: $mkiot -f examples/scratch/static-hello-world/buildspec.yaml"
	echo >&2 "   ie: $mkiot -f examples/debian/hello-world/buildspec.yaml"
	echo >&2 "   ie: $mkiot -f examples/debian/hello-world/buildspec.yaml debian"
	echo >&2 "   ie: $mkiot -f examples/debian/hello-world/buildspec.yaml debian --variant=minbase stretch"
	echo >&2 "       $mkiot -f buildspec.yaml ubuntu --include=ubuntu-minimal --components=main,universe trusty"
	echo >&2 "       $mkiot -f buildspec.yaml busybox-static"
	echo >&2 "       $mkiot -f buildspec.yaml alpine  busybox-static"
	exit 1
}

user=$SUDO_USER

optTemp=$(getopt --options '+f:a:t:hrC' --longoptions 'file:,remove,arch:,tag:,compression:,no-compression,help' --name "$mkimg" -- "$@")
eval set -- "$optTemp"
unset optTemp

ARCH=
BASE_IMAGE_RELEASE=
BASE_IMAGE=
BUILD_SPEC=
ARTIFACTS_COMPRESSION="tar"
ARTIFACTS_NAME=
REMOVE_PREVIOUS="false"
while true; do
	case "$1" in
                -a | --arch)
                        ARCH="$2"
                        shift 2
                        ;;
		-f | --file)
			BUILDSPEC="$2"
			shift 2
			;;
		-t | --tag)
			TAG="$2"
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
                -r | --remove)
                        REMOVE_PREVIOUS="true"
                        shift 1
                        ;;
		-h | --help) usage ;;
		--)
			shift
			break
			;;
	esac
done

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

if [ -z "$BUILDSPEC" ]; then
        error "-b 'buidspec.yaml' was not passed"
        usage
fi

if [ ! -f "$BUILDSPEC" ]; then
        error "could not find '$BUILDSPEC' file"
        usage
fi

if [ "$(id -u)" -ne "0" ]; then
        >&2 echo "Error: must be root"
        exit 1
fi

if [ -z "$ARCH" ]; then
        ARCH=$(get_yaml_value "$BUILDSPEC" "arch")
fi

export BASE_DIRECTORY=$(get_yaml_value "$BUILDSPEC" "\"base-directory\"")
if [ -z "$BASE_DIRECTORY" ]; then
        info "'base-directory' of build output not set, using './output/'"
        export BASE_DIRECTORY="output/"
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

export CHROOT_CONTAINER=$(which systemd-nspawn)

time="$(date +%F_%H%M%S)"

run_commands() {
        export ROOTFS="$1"
        local phase="$2"
        local idx="$3"
        local shell="$4"

        # Walk now command instructions and run them
        for comsidx in {0..40}
        do
                local cmdline=$(get_yaml_value "$BUILDSPEC" "$(printf %s "phases${phase} | .[$idx].commands[$comsidx]")")
                if [ "$cmdline" == "null" ]; then
                        break
                fi

                (
                        set -x
                        # expand cmdline on purpose
                        if [ -z "$shell" ] || [ "$shell" == "null" ]; then
                                run_yaml_commands $cmdline
                        else
                                run_yaml_commands "--shell=$shell" $cmdline
                        fi
                )
        done
}

run_phases_installs() {
        local idx="$1"
        shift 1
        local build_args="$@"

        if [ "$BASE_IMAGE" == "debian" ]; then
                # Set default release mirror values
                . ${mkiot_path}/mkimage/$BASE_IMAGE/install
        fi

        if [ -z "$BASE_IMAGE" ]; then
                fatal "'phases.installs[$idx].image or base image is not set in buildspec and no default value"
        fi

        export BASE_IMAGE_RELEASE=$(get_yaml_value "$BUILDSPEC" "$(printf %s "phases.installs | .[$idx].release")")
        if [ -z $BASE_IMAGE_RELEASE ]; then
                # Use default release
                export BASE_IMAGE_RELEASE=$release
        fi

        export BASE_IMAGE_MIRROR=$(get_yaml_value "$BUILDSPEC" "$(printf %s "phases.installs | .[$idx].mirror")")
        if [ -z $BASE_IMAGE_MIRROR ]; then
                # Use default mirror
                export BASE_IMAGE_MIRROR=$mirror
        fi

        if [ -z "$BASE_IMAGE_MIRROR" ]; then
                fatal "'phases.installs[$idx].mirror' for image '$BASE_IMAGE' is not set in buildspec and no default value"
        fi

        mkdir -p ${BASE_DIRECTORY}
        chown ${user}.${user} ${BASE_DIRECTORY}

        export INSTALLS_NAME=$(get_yaml_value "$BUILDSPEC" "$(printf %s "phases.installs | .[$idx].name")")
        if [ -z "$INSTALLS_NAME" ]; then
                export INSTALLS_NAME="install-$idx-output-$time"
        fi

        local install_args=$(get_yaml_value "$BUILDSPEC" "$(printf %s "phases.installs | .[$idx][\"install-args\"]")")
        if [ "$install_args" == "null" ]; then
                # clear them up
                install_args=""
        fi

        info "phases.installs[$idx] OS '$BASE_IMAGE' into 'image=${BASE_DIRECTORY}/${INSTALLS_NAME}'"

        local reuse="false"
        local cache=$(get_yaml_value "$BUILDSPEC" "$(printf %s "phases.installs | .[$idx].cache")")
        if [ -a ${BASE_DIRECTORY}/${INSTALLS_NAME} ]; then
                if [ "$cache" == "null" ]; then
                        info "found image install at '${BASE_DIRECTORY}/${INSTALLS_NAME}'"
                        info "removing image '${BASE_DIRECTORY}/${INSTALL_NAME}', \
                                set 'cache: \"reuse\" to reuse old images"
                        rm -fr -- ${BASE_DIRECTORY}/${INSTALLS_NAME}
                elif [ "$cache" == "reuse" ]; then
                        reuse="true"
                else
                        fatal "image already exists at '${BASE_DIRECTORY}/${INSTALLS_NAME}', \
                                set 'cache: '$cache'' value not supported"
                fi
        fi

        if [ "$reuse" == "false" ]; then
                local builddir="$(mktemp -d ${BASE_DIRECTORY}/${INSTALLS_NAME}.XXXXXXXXXXX.tmp)"

                export ROOTFS="$builddir"
                (
	                set -x
	                mkdir -p "$ROOTFS"
                )

                mkdir -p ${ROOTFS}
                chown ${user}.${user} ${ROOTFS}

                echo
                info "Building with: 'buildspec=$BUILDSPEC' phases.installs[$idx] 'arch=$ARCH' 'image=$BASE_IMAGE' 'release=$BASE_IMAGE_RELEASE' \
'base-directory=$BASE_DIRECTORY' 'name=$INSTALLS_NAME' 'install-args=$install_args $build_args'"

                if [[ "$BASE_IMAGE_MIRROR" == *"ionoid"* ]]; then
                        "${mkiot_path}/mkimage/ionoid-bootstrap.bash" --arch="$ARCH" "$install_args" "$build_args"
                elif [ "$BASE_IMAGE" == "debian" ]; then
                        # pass all remaining arguments to $script
                        "${mkiot_path}/mkimage/debootstrap" --arch="$ARCH" "$install_args" "$build_args"
                else
                        fatal "unsupported target image '$BASE_IMAGE'"
                fi
        
                #
                # Make sure to point back rootfs to INSTALLS_NAME,
                # it will be picked later by next phases
                #
                mv -f "$ROOTFS" "${BASE_DIRECTORY}/${INSTALLS_NAME}"

        else
                echo
                info "Reusing image: phases.installs[$idx] 'arch=$ARCH' 'image=$BASE_IMAGE' 'release=$BASE_IMAGE_RELEASE' \
'base-directory=$BASE_DIRECTORY' 'name=$INSTALLS_NAME' 'install-args="
        fi

        local shell=$(get_yaml_value "$BUILDSPEC" "$(printf %s "phases.installs | .[$idx].shell")")

        # Lets run commands from the installs phase
        run_commands "${BASE_DIRECTORY}/${INSTALLS_NAME}" ".installs" "$idx" "$shell"

        info "phases.installs[$idx] finished, image location: ${BASE_DIRECTORY}/$INSTALLS_NAME"
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

        info "phases.pre-builds[$idx] started on 'image=${BASE_DIRECTORY}/${use_image}'"

        local shell=$(get_yaml_value "$BUILDSPEC" "$(printf %s "phases[\"pre-builds\"] | .[$idx].shell")")

        # Lets run commands from the installs phase
        run_commands "${BASE_DIRECTORY}/${use_image}" "[\"pre-builds\"]" "$idx" "$shell"

        info "phases.pre-builds[$idx] finished, image location: ${BASE_DIRECTORY}/${use_image}"
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

        info "phases.builds[$idx] started on 'image=${BASE_DIRECTORY}/${use_image}'"

        local shell=$(get_yaml_value "$BUILDSPEC" "$(printf %s "phases.builds | .[$idx].shell")")

        # Lets run commands from the installs phase
        run_commands "${BASE_DIRECTORY}/${use_image}" ".builds" "$idx"

        info "phases.builds[$idx] finished, image location: ${BASE_DIRECTORY}/${use_image}"
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

        info "phases.post-builds[$idx] started on 'image=${BASE_DIRECTORY}/${use_image}'"

        local shell=$(get_yaml_value "$BUILDSPEC" "$(printf %s "phases[\"post-builds\"] | .[$idx].shell")")

        # Lets run commands from the installs phase
        run_commands "${BASE_DIRECTORY}/${use_image}" "[\"post-builds\"]" "$idx"

        info "phases.post-builds[$idx] finished, image location: ${BASE_DIRECTORY}/${use_image}"
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

        info "Generated artifact at: '${dir}/${file}'"
}

generate_artifact() {
        local idx="$1"
        export ARTIFACTS_NAME="$2"
        export ARTIFACTS_BASE_DIRECTORY="$BASE_DIRECTORY/artifacts/"

        mkdir -p ${ARTIFACTS_BASE_DIRECTORY}
        chown ${user}.${user} ${ARTIFACTS_BASE_DIRECTORY}

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
        rm -fr "${ARTIFACTS_BASE_DIRECTORY}/${artifact}"
        mkdir -p "${ARTIFACTS_BASE_DIRECTORY}/${artifact}"

        for i in {0..20}
        do
                local file=$(get_yaml_value "$BUILDSPEC" "$(printf %s "artifacts | .[$idx].files[$i]")")
                if [ "$file" == "null" ]; then
                        break
                fi

                if [ -d "${BASE_DIRECTORY}/${file}" ]; then
                        cp -dfR --preserve=all "${BASE_DIRECTORY}/${file}/." "${ARTIFACTS_BASE_DIRECTORY}/${artifact}"
                else
                        error "failed to add '${BASE_DIRECTORY}/${file}' content to artifact: not a directory"
                        break
                fi
        done

        local compression=$(get_yaml_value "$BUILDSPEC" "$(printf %s "artifacts | .[$idx].compression")")

        compress_artifact "${ARTIFACTS_BASE_DIRECTORY}" "${compression}" "${artifact}"

        rm -fr "${ARTIFACTS_BASE_DIRECTORY}/${artifact}"
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
        artifacts_name=$(get_yaml_value "$BUILDSPEC" "$(printf %s "artifacts | .[$i].name")")
        if [ -z "$artifacts_name" ] || [ "$artifacts_name" == "null" ]; then
                break
        fi

        generate_artifact "$i" "$artifacts_name"
        artifacts_name="null"
done

exit 0
