#!/bin/bash

main() {
        local INSTALL_DIR="/usr/lib/mkiot/"

        install -m 755 mkiot.bash "/usr/bin/"
        c=$(pwd)
        cd "/usr/bin/"
        ln -sfr ./mkiot.bash ./mkiot
        cd "$c"

        install -d $INSTALL_DIR
        cp -fr examples ${INSTALL_DIR}
        cp -fr mkimage ${INSTALL_DIR} 
        install -m 755 LICENSE ${INSTALL_DIR}
        install -m 755 install.bash ${INSTALL_DIR}
        install -m 755 uninstall.bash ${INSTALL_DIR}
        cp -fr docs ${INSTALL_DIR}

        echo "Info: install 'mkiot': success"
}

main $@
