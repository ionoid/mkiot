# Make IoT - Build IoT Apps

A wrapper around `debootstrap` to build lightweight IoT Apps.


## Build Spec

`mkiot` make it simple to build IoT apps artifacts that are ready to be deployed to IoT devices.

Internally It uses `debootstrap` and other classic Linux tools. `mkiot` provides these benefits:

* Produces classic archives format: `zip` and `tar` files.

* Supports multi-stage builds to produce lightweight IoT apps.

* Only the build envrionment is defined, the runnin or execution environment is not defined.


### Build Spec syntax

Build specs are expressed in [YAML](https://yaml.org) format.

If a field contains a character, or a string of characters, that is not supported by YAML,
you must enclose the command in quotation marks (""). The following command is enclosed in
quotation marks because a colon (:) followed by a space is not allowed in YAML.
The quotation mark in the command is escaped (\"). [1] Reference.

```bash
"export PACKAGE_NAME=$(cat package.json | grep name | head -1 | awk -F: '{ print $2 }' | sed 's/[\",]//g')"
```


IoT buildspec format:

```yaml
version: 0.1

arch: armhf
build-directory: build/

env:
        variables:
                key: "value"
                key1: "value"

cache:
        images:
                - /var/lib/mkiot/images/cache/

phases:
        installs:
                - image: debian
                  mirror: http://deb.debian.org/debian/
                  release: stretch
                  name: debian-armhf-dev
                  cache: "save,reuse"
                  install-args:
                  runtime-versions:
                  commands:
                        - ["command"]
                        - ["command", "arg1", "arg2" ]

                - image: debian
                  name: debian-armhf-prod
                  cache: "reuse"
                  install-args:
                  shell: "bash"


        pre-builds:
                # Set what image to use from installs
                - use: debian-armhf-dev
                  commands:
                        - ["command"]
                        - script scriptfile /bin/scriptfile

        builds:
                # Set what image to use from installs
                - use: debian-armhf-dev
                  commands:
                        - ["command"]
                        - ["command"]
                        - ["command"]

                # Use debian-armhf-prod image as target
                - use: debian-armhf-prod
                  commands:
                        # copy from dev image to prod image
                        - ["copy", "--from=debian-armhf-dev", "source_file", "destination_file" ]
                        - ["command"]

        post-builds:
                - use: debian-armhf-prod
                  commands:
                        - ["command"]
                        - ["command"]
                        - ["command"]

artifacts:
        - name: debian-stretch-armhf
          suffix: date +%Y-%m-%d
          image: debian-armhf-prod
          files:
                - file
          compression: tar

```


* `version`: represents the buildspec version. Required field.

* `arch`: required fields represents the target board architecture. Possible values are: `i386`, `amd64`, `armhf` and `arm64`.

* `build-directory`: required field represents the location where to produce builds.

* `env`: optional field contains environment variables that are passed to all commands of the buildpsec. The environment variables are inside `variables` as keys and values.

* `cache`: optional cache where to find previous images that were downloaded and cached. This allows to not download images again.

* `phases`: Represents the different phases of a build. Required field must contain `installs` phase and at least one of the `pre-builds`, `builds` or `post-builds` phases.

    * `installs`: a list of different images to install to build the application. This should be used to only download images, use the ones from the cache and install packages for the build environment.
    


## Install

mkiot needs the following packages:

- qemu qemu-user-static
```bash
        sudo apt-get install qemu qemu-user-static
```

- binfmt-support
```bash
        sudo apt-get install binfmt-support
```

- systemd-container or systemd-nspawn
```bash
        sudo apt-get install systemd-container
```

- deboostrap
```bash
        sudo apt-get install debootstrap
```

- yq: Command-line YAML/XML processor  https://kislyuk.github.io/yq/
```bash
        pip install yq
```


Of course it needs other tools that should be installed: "python, bash, tar, zip"


## References

[1] https://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html
