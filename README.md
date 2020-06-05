# Make IoT - Build IoT Apps

A wrapper around `debootstrap` to build lightweight IoT Apps.


## Build Spec

`mkiot` make it simple to build IoT apps artifacts that are ready to be deployed to IoT devices.

Internally It uses `debootstrap` and other classic Linux tools. `mkiot` provides these benefits:

* Produces classic archives format: `zip` and `tar` files.

* Supports multi-stage builds to optimize images and produce lightweight IoT apps.

* Only the build envrionment is defined, the execution environment is not defined nor enforced.


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
                  release: buster
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
                        - ["script", "scriptfile", "/bin/scriptfile"]

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
        - use: debian-armhf-prod
          name: debian-stretch-armhf
          suffix: date +%Y-%m-%d
          files:
                - file
          compression: tar

```


* `version`: represents the buildspec version. Required field.

* `arch`: required fields represents the target board architecture. Possible values are: `i386`, `amd64`, `armhf` and `arm64`.

* `build-directory`: required field represents the location where to produce builds.

* `env`: optional field contains environment variables that are passed to all commands of the buildpsec. The environment variables are inside `variables` as keys and values.

* `cache`: optional cache where to find previous images that were downloaded and cached. This allows to not download images again. By default it is set to `/var/lib/mkiot/images/cache/`.

* `phases`: Represents the different phases of a build. This is a required field must contain the `installs` phase and at least one of the `pre-builds`, `builds` or `post-builds` phases.

    * `installs`: a list of different images to install that are necessary to build and produce the application artifact. This should be used to only download images or use the ones from the cache to install packages.

        * `image`: required field in `installs` contains the base distribution name to use as a file system for the application.

        * `mirror`: optional field to define the mirror where to download the distribution from.

        * `release`: optional field to define the release code name of distribution to use.
        
        * `name`: required field to define how to name the directory that contains the downloaded distribtion or the one that was copied from cache.

        * `cache`: optional field to specify how to use the cache. Possible values are `save`, `reuse` or both separated by `,`. Save means after finishing downloading this image and executing the commands save it into cache for future usage. Reuse means if this image is in the cache do not download it again and just copy it into the `build-directory` and use it.

        * `commands`: optional sequence of commands with their arguments that are executed according to their order. Command example: `["/bin/echo", "hello"]`.

    * `pre-builds`: optional sequence of commands to prepare the build environment.

        * `use`: the name of the image to use. It has to be the `name` field of one of the images that were installed during the `installs` phase.

        * `commands`: optional sequence of commands with their arguments that are executed according to their order. Command example: `["/bin/echo", "hello"]`.

    * `builds`: optional sequence of commands to build the application.

        * `use`: the name of the image to use. It has to be the `name` field of one of the images that were installed during the `installs` phase.

        * `commands`: optional sequence of commands with their arguments that are executed according to their order. Command example: `["/bin/echo", "hello"]`.

    * `post-builds`: optional sequence of commands to run after the build. These can be used to produce final files necesary to build the artifact, clean up files or even push notifications.

        * `use`: the name of the image to use. It has to be the `name` field of one of the images that were installed during the `installs` phase.

        * `commands`: optional sequence of commands with their arguments that are executed according to their order. Command example: `["/bin/echo", "hello"]`.


* `artifacts`: required field that specifies how to produce the final artifacts. All produced artifacts can be found inside the `$build-directory/artifacts/` directory.

    * `use`: the name of the image to use. It has to be the `name` field of one of the images that were installed during the `installs` phase.

    * `name`: required field to define how to name the final artifact that contains the build output.

    * `compression`: specifies the archive and compression format to use, by default it uses the `tar archive` format.


### Build specs extra documentation
        
#### Commands

Commands are sequences that are executed inside the image or the build environment one at a time, in the order listed.
Each command can be any command that refers to a binary or shell command inside the image, beside that there are some
special commands that will make it easy to automate the build process

During the `installs` phase, commands are executed inside the image environment that was named by the `name` field.
During other build stages, commands are executed inside the image environment that was specified by the `use` field.


* `script`: the script command allows to pass directly a script inside the image and execute it, it is done by bind mounting the script inside the image. This is useful instead of passing multiple sequences of commands; the commands are inside the script file which is executed. The script can be either `bash`, `python` etc. Please note that the script will not be copied inside the image.

    * `script` syntax: the `script` command syntax is: `[ "script", "scriptfile", "/bin/scriptfile" ]`
    
        * `"script"`: first element is the command.
        
        * `"scriptfile"`: the second element is the script file location on the host file system.
        
        * `"/bin/scriptfile"`: last element is optional. Specify where to make the script available inside the image. Usually using `/bin/` inside image is enough which is the default operation anyway if the third element is not specified.


* `copy`: the copy command allows to copy files and directories between multiple images and local file system. Internally it invokes the Unix `cp` command with `-a` as argument so directories are copied recursively with permissions preserved if possible. For further details please read [cp manual](https://linux.die.net/man/1/cp).

    * `copy` syntax: the `copy` command syntax is: `["copy", "--from=image-name", "source", "destination" ]

        * `"copy"`: first element is the command.

        * `"--from=image-name"`: second element is optional and allows to copy files and directories from other images and build envrionments to perform multi-stage builds. The `image-name` must be a `name` field of one of the images that were installed during the `installs` phase.

        * `"source"`: specifies the source files or directories to be copied from host or another image into the target image name that was specified inside the `use` field.

        * `"destination"`: specifies the destination inside the image environment where to copy the files or directories.


## Install

mkiot needs the following packages:

- qemu qemu-user-static
```bash
        sudo apt-get install qemu qemu-user-static


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
