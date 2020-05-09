#!/bin/bash

main() {
        local INSTALL_DIR="/usr/lib/mkiot/"

        install -m 755 mkiot.bash "/usr/bin/"

        install -d $INSTALL_DIR
        cp -fr examples ${INSTALL_DIR}
        cp -fr mkimage ${INSTALL_DIR} 
        install -m 755 LICENSE ${INSTALL_DIR}
        install -m 755 install.bash ${INSTALL_DIR}
        install -m 755 uninstall.bash ${INSTALL_DIR}
        cp -fr docs ${INSTALL_DIR}
}

main $@
