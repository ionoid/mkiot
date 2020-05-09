#!/bin/bash

main() {
        local INSTALL_DIR="/usr/lib/mkiot/"

        rm -fr "${INSTALL_DIR}"
        rm -fr "/usr/bin/mkiot.bash"
}

main $@
