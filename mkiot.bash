#!/bin/bash

# Copyright (C) 2020 Open Devices GmbH
# Copyright (C) 2020 Harouni Djalal <tixxdz@opendevices.io>

mkiot="$(basename "$0")"
export mkiot_path="$(dirname "$(readlink -f "$BASH_SOURCE")")"

set -e

if [ "$(id -u)" -ne "0" ]; then
        echo "Error: must be root"
        exit 1
fi

# Lets unshare the mount namespace first
unshare -m "${mkiot_path}/mkimage/buildspec-main.bash" "$@"
