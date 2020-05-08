# Make IoT - Build IoT Apps

A wrapper around `debootstrap` to build lightweight IoT Apps.


## Build Spec


### Build Spec syntax

Build specs are expressed in [YAML](https://yaml.org) format.

If a command contains a character, or a string of characters, that is not supported by YAML,
you must enclose the command in quotation marks (""). The following command is enclosed in
quotation marks because a colon (:) followed by a space is not allowed in YAML.
The quotation mark in the command is escaped (\"). [1] Reference.

```bash
"export PACKAGE_NAME=$(cat package.json | grep name | head -1 | awk -F: '{ print $2 }' | sed 's/[\",]//g')"
```

IoT Apps have the following buildspec format:

```yaml
version: 0.1

arch: armhf
base-directory: build/

phases:
        installs:
                - image: debian
                  mirror: http://deb.debian.org/debian/
                  release: stretch
                  name: debian-armhf-dev
                  cache: "reuse"
                  install-args:
                  runtime-versions:
                  commands:
                        - command
                        - command

                - image: debian
                  mirror: http://deb.debian.org/debian/
                  release: stretch
                  name: debian-armhf-prod
                  cache: "reuse"
                  install-args:


        pre-builds:
                # Set what image to use from installs
                - use: debian-armhf-dev
                  commands:
                        - command

        builds:
                # Set what image to use from installs
                - use: debian-armhf-dev
                  commands:
                        - command
                        - command
                        - command

                # Use debian-armhf-prod image as target
                - use: debian-armhf-prod
                  commands:
                        # copy from dev image to prod image
                        - copy --from=debian-armhf-dev source destination
                        - command

        post-builds:
                - use: debian-armhf-prod
                  commands:
                        - command
                        - command
                        - command

artifacts:
        - name: debian-stretch-armhf
          suffix: date +%Y-%m-%d
          files:
                - debian-armhf-prod
          compression: tar

```



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




## References

[1] https://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html
