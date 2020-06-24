#!/bin/bash

set -e

main() {
        local INSTALL_DIR="/usr/lib/mkiot/"
        local MKIOT_CACHE="/var/cache/mkiot/"

        rm -fr "${INSTALL_DIR}"
        rm -fr "${MKIOT_CACHE}"
        rm -f "/usr/bin/mkiot"
        rm -f "/usr/bin/mkiot.bash"

        echo "Info: uninstall 'mkiot': success"
}

main $@
