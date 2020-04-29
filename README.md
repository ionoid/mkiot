# Make IoT - Build IoT Apps

A wrapper around `debootstrap` to build lightweight IoT Apps.



## Install

mkiot needs the following packages:

- qemu qemu-user-static
        sudo apt-get install qemu qemu-user-static

- binfmt-support
        sudo apt-get install binfmt-support

- systemd-container or systemd-nspawn
        sudo apt-get install systemd-container

- deboostrap
        sudo apt-get install debootstrap

- yq: Command-line YAML/XML processor  https://kislyuk.github.io/yq/
        pip install yq



Of course it needs other tools that should be installed tar, zip etc
