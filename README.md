<div align="center">
	<img style="width:100%;" src="mkiot-logo.png" alt="ionoid.io mkiot">
	<h4>
		Building IoT Apps Made Easy - The <a href="https://ionoid.io/" target="_blank">Ionoid.io</a> Make IoT Tool
	</h4>
	<p align="center">
		<br />
		<a href="https://ionoid.io/">Website</a>
		·
		<a href="https://docs.ionoid.io/">Documentation</a>
		·
		<a href="https://dashboard.ionoid.io/">Dashboard</a>
	</p>
	<p align="center">
		<sub>Copyright <a href="https://www.opendevices.io/" target="_blank">Open Devices GmbH ©</a> 2020 All Rights Reserved</sub>
	</p>

</div>

<br/>

<h1 align="center">Make IoT - Build Linux IoT and Edge Apps</h1>

<div align="center">
	
The **mkiot** tool build IoT apps artifacts for Linux IoT and Edge devices.

The **mkiot** tool is a product maintained by <a href="https://ionoid.io/" targe="_blank">Ionoid.io</a> - The IoT next generation deployment.
	
</div>

<h1 align="center">Supported Images and Environments</h1>

<div align="center">
	<table>
		<tr>
			<td>
				<a href="https://www.debian.org/" target="_blank">
					<img src="logos/debian-logo.png" style="" alt="Debian" title="Debian" />
				</a>
			</td>
    			<td>
				<a href="https://alpinelinux.org/" target="_blank">
					<img src="logos/alpine-linux-logo.png" style="" alt="Alpine Linux" title="Alpine Linux" />
				</a>
			</td>
    			<td>
				<a href="https://ubuntu.com/" target="_blank">
					<img src="logos/ubuntu-logo.png" style="" alt="Ubuntu" title="Ubuntu" />
				</a>
			</td>
  		</tr>
		<tr>
			<td align="center">Debian</td>
			<td align="center">Alpine Linux</td>
			<td align="center">Ubuntu</td>
		</tr>
  		<tr>
    			<td>
				<a href="https://www.raspberrypi.org/" target="_blank">
					<img src="logos/raspberry-logo.png" style="" alt="Raspberry Pi" title="Raspberry Pi" />
				</a>
			</td>
    			<td>
				<a href="https://nodejs.org/en/" target="_blank">
					<img src="logos/nodejs-logo.png" style="" alt="Node.js" title="Node.js" />
				</a>
			</td>
    			<td>
				<a href="https://www.python.org/" target="_blank">
					<img src="logos/python-logo.png" style="" alt="Python" title="Python" />
				</a>
			</td>
  		</tr>
		<tr>
			<td align="center">Raspberry Pi</td>
			<td align="center">Node.js</td>
			<td align="center">Python</td>
		</tr>
	</table>
</div>

<h1 align="center">Supported Apps</h1>

<div align="center">
	<table>
		<tr>
			<td>
				<a href="https://nodered.org/" target="_blank">
					<img src="logos/node-red-logo.png" style="" alt="Node red" title="Node-RED" />
				</a>
			</td>
  		</tr>
		<tr>
			<td align="center">Node-RED</td>
		</tr>
	</table>
</div>

## Index

- [Introduction](#introduction)
- [How to Install](#install)
- [The Build Spec Syntax](#build-spec-syntax)
- [Some Examples](#examples)
- [Multi-Stage Builds](#multi-stage-builds)

## Introduction

The `mkiot` tool makes it easy to build IoT apps and artifacts for Linux IoT and Edge devices. Internally It uses `debootstrap` and other classic Linux tools. `mkiot` provides these benefits:

- Produces classic archives format: `tar archive` files, or supported compressed files over `tar`
- Supports multi-stage builds to optimize images and produce lightweight IoT apps
- Only the build envrionment is defined, the execution environment is not defined nor enforced
- Deploy produced artifcats to your IoT and Edge devices with [Ionoid.io](https://ionoid.io) using the [Deploy Apps](https://docs-dev.ionoid.io/docs/deploy-iot-apps.html#deploy-iot-apps) feature from [https://dashboard.ionoid.io/](Ionoid.io Dashboard).

> Security Note
>
> Do not run buildspec files nor use images from **untrusted parties**, this may harm your system. Always
> make sure that the buildspec or the image urls inside it originated from a trusted source.

## How to Install

### Prepare Dependencies

The `mkiot` tool needs the following packages: `qemu`, `qemu-user-static`, `binfmt-support`, `systemd-nspawn`, `deboostrap`,
`yq` and `pyyaml`.

Of course it also needs other tools that should already be installed on standard Linux distributions like
`python`, `bash`, `tar`, `gzip`, etc...

To install the necessary dependencies on Debian based operating systems:

```bash
sudo apt-get install qemu qemu-user-static binfmt-support systemd-container debootstrap
```

and:

```bash
sudo pip install -U yq pyyaml
```

### Install Make IoT

Start by cloning the current repository:

```bash
git clone https://github.com/ionoid/mkiot.git
cd mkiot
```

To install run the following command:

```bash
sudo ./install.bash
```

If you want to uninstall, run:
```bash
sudo ./uninstall.bash
```

## The Build Spec Syntax

The `mkiot` tool uses build specs that are expressed in [YAML](https://yaml.org)
format to define how to build the application image. If a field contains a character that is not supported by YAML,
you must enclose the command in quotation marks ("").

The buildspec file structure looks like this:

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
        - ["command_1"]
        - ["command_2"]
        - ["command_3"]

    # Use debian-armhf-prod image as target
    - use: debian-armhf-prod
      commands:
        # copy from dev image to prod image
        - ["copy", "--from=debian-armhf-dev", "source_file", "destination_file" ]
        - ["command"]

  post-builds:
    - use: debian-armhf-prod
      commands:
        - ["command_1"]
        - ["command_2"]
        - ["command_3"]

artifacts:
  - use: debian-armhf-prod
    name: debian-stretch-armhf
    suffix: date +%Y-%m-%d
    commands:
      - ["copy", "app.yaml", "app.yaml" ]
    files:
      - app.yaml app.yaml
      - file.conf /etc/file.conf
    compression: tar

```

Here is what each option means:

* `version`: the buildspec version (*Required*).
* `arch`: the target board architecture. Possible values are: `i386`, `amd64`, `armhf` and `arm64` (*Required*).
* `build-directory`: the location where to reproduce builds. If not set default location will be `mkiot-output` in the current directory (*Optional*).
* `env`: the environment variables that are passed to all commands of the buildpsec. The environment variables are inside `variables` as keys and values (*Optional*).
* `cache`: the cache where to find previous images that were downloaded and cached. By default it is set to `/var/lib/mkiot/images/cache/`. Please do not set this unless you know what you are doing, in this case you have to cleanup the cache manually. Images inside the default cache folder `/var/lib/mkiot/images/cache/` that are older than 60 days will be removed at next `mkiot` run (*Optional*).
* `phases`: the different phases of a build. This field must contain the `installs` phase and at least one of the `pre-builds`, `builds` or `post-builds` phases (*Required*).
  * `installs`: a list of different images to install that are necessary to build and produce the application artifact. This should be used to only download images or use the ones from the cache to install packages.
    * `image`: it contains the base distribution name to use as a file system for the application. Current supported values are [Debian](https://www.debian.org/), and `scratch` for an empty Linux file system. For security reasons do not use untrusted sources or URLs for your images, as `mkiot` runs will privileges this may harm your system, if you download or use images or buildspecs from untrusted parties (*Required*).
      * `mirror`: it defines the mirror where to download the distribution from (*Optional*).
      * `release`: it defines the release code name of distribution to use (*Optional*).
      * `name`: it defines how to name the directory that contains the downloaded distribution or the one that was copied from cache (*Required*).
      * `cache`: it specifies how to use the cache. Possible values are `save`, `reuse` or both separated by `,`. `save` means after finishing downloading this image and executing the commands save it into cache for future usage, overwriting any previous saved image that has same `name` field. `reuse` means if this image is in the cache do not download it again and just copy it into the `build-directory` and use it (*Optional*).
      * `commands`: a sequence of commands with their arguments that are executed according to their order. For example `["/bin/echo", "hello"]` (*Optional*).
    * `pre-builds`: a sequence of commands to prepare the build environment (*Optional*).
      * `use`: the name of the image to use. It has to be the `name` field of one of the images that were installed during the `installs` phase.
      * `commands`: a sequence of commands with their arguments that are executed according to their order. For example `["/bin/echo", "hello"]` (*Oprional*).
    * `builds`: a sequence of commands to build the application (Optional).
      * `use`: the name of the image to use. It has to be the `name` field of one of the images that were installed during the `installs` phase.
      * `commands`: a sequence of commands with their arguments that are executed according to their order. For example `["/bin/echo", "hello"]` (*Optional*).
    * `post-builds`: a sequence of commands to run after the build. These can be used to produce final files necesary to build the artifact, clean up files or even push notifications (*Optional*).
      * `use`: the name of the image to use. It has to be the `name` field of one of the images that were installed during the `installs` phase.
      * `commands`: optional sequence of commands with their arguments that are executed according to their order. For example `["/bin/echo", "hello"]`.
* `artifacts`: it specifies how to produce the final artifacts. All produced artifacts can be found inside the `$build-directory/artifacts/` directory (*Required*).
  * `use`: the name of the image to use. It has to be the `name` field of one of the images that were installed during the `installs` phase (*Required*).
  * `name`: it contains the name the final artifact. If not set it will use the same name of the field `use` (*Optional*).
  * `suffix`: it will be appended to the name of the final artifact. This can be a bash command where the output is the `suffix` (*Optional*).
  * `commands`: a sequence of commands with their arguments that are executed according to their order. For example: `["/bin/echo", "hello"]`. This can be used to copy files and directories into the final artifacts. As an example an `app.yaml` file that defines how to run the application (*Optional*).
  * `files`: a sequence of files and directories that are copied from the host file system into the final artifact. First element is the file or directory location on the host, and second element is where to copy the files or directories inside the artifact. This field can be used to copy an `app.yaml` file definition of an [IoT App](https://docs-dev.ionoid.io/docs/iot-apps.htm) inside the artifact to be deployed using [Ionoid.io](https://ionoid.io/) (*Optional*).
  * `compression`: specifies the archive and compression format to use, by default, if not set the procuded articact will be a `tar archive` file.
    Supported compression formats: `tar.gz` (*Optional*).

### The Build Spec Commands Documentation

Commands are sequences that are executed inside the image or the build environment one at a time, in the order listed.
Each command can be any command that refers to a binary or shell command inside the image, beside that there are some
special commands that will make it easy to automate the build process

During the `installs` phase, commands are executed inside the image environment that was named by the `name` field.
During other build stages, commands are executed inside the image environment that was specified by the `use` field.


* `script`: the script command allows to pass directly a script inside the image and execute it, it is done by bind mounting the script inside the image. This is useful instead of passing multiple sequences of commands; the commands are inside the script file which is executed. The script can be either `bash`, `python` etc. Please note that the script will not be copied inside the image.

    * `script` syntax: the `script` command syntax is: `[ "script", "scriptfile", "/bin/scriptfile" ]`
    
        * `"script"`: first element is the command `script`.
        
        * `"scriptfile"`: the second element is the script file location on the host file system. This can be located inside the same directory where the current `buildspec.yaml` file is.
        
        * `"/bin/scriptfile"`: last element is optional. Specify where to make the script available inside the image. Usually using `/bin/` inside image is enough which is the default operation anyway if the third element is not specified.


* `copy`: the copy command allows to copy files and directories between multiple images and local file system. Internally it invokes the Unix `cp` command with `-a` as argument so directories are copied recursively with permissions preserved if possible. For further details please read [cp manual](https://linux.die.net/man/1/cp).

    * `copy` syntax: the `copy` command syntax is: `["copy", "--from=image-name", "source", "destination" ]

        * `"copy"`: first element is the command.

        * `"--from=image-name"`: second element is optional and allows to copy files and directories from other images and build envrionments to perform multi-stage builds. The `image-name` must be a `name` field of one of the images that were installed during the `installs` phase.

        * `"source"`: specifies the source files or directories to be copied from host or another image into the target image name that was specified inside the `use` field.

        * `"destination"`: specifies the destination inside the image environment where to copy the files or directories.


## Some Examples

The following examples demonstrate how to build an IoT package for Linux. The package includes the application with all its
dependencies inside a `tar archive` file. There are multiple Linux distributions that can be used as a base file system
for applications, the next section details this more.

Possible values of `arch` inside buildspec files are: `i386`, `amd64`, `armhf` and `arm64`.


### Debian Based Images

[Debian](https://www.debian.org/) is a free operation system (OS) for PC. Using `mkiot` tools we can build a minimal Debian
based file system for applications without a Linux kernel nor other tools needed to run a complete OS. `mkiot` makes use
of [debootstrap](https://wiki.debian.org/Debootstrap) to install the system.


* Minimal Debian file system:
```bash
sudo mkiot build examples/debian/buildspec.yaml
```

* Development Debian with build essential packages:
```bash
sudo mkiot build examples/devtools/debian/buster/buildspec-devtools-armhf.yaml
```

#### Node.js based on Debian

* [Node.js
package](https://nodejs.org/en/download/package-manager/#debian-and-ubuntu-based-linux-distributions-enterprise-linux-fedora-and-snap-packages) from usptream with minimal debian:
```bash
sudo mkiot build examples/node.js/debian/buster/buildspec-node.js-minimal-debian-armhf.yaml
```

* Node.js binary from upstream with extra `devtools`, `build essential` and `yarn` installed:
```bash
sudo mkiot build examples/node.js/14/buster/buildspec-node.js-devtools-debian-armv7l.yaml
```

* [Node-RED](https://nodered.org/) app example:
Please follow this example: [build Node-RED](examples/apps/node-red) and deploy it to your devices.


#### Python based on Debian

* Python2 on minimal Debian with some development packages:
```bash
sudo mkiot build examples/python/debian/buster/buildspec-python2-minimal-debian-armhf.yaml
```

* Python3 with minimal file system:
```bash
sudo mkiot build examples/python/debian/buster/buildspec-python3-minimal-debian-armhf.yaml
```

* Python3 with extra devtools file system:
```bash
sudo mkiot build examples/python/debian/buster/buildspec-python3-devtools-debian-armhf.yaml
```


#### Golang based on Debian

For Golang we recommend to use the same architecture of the host, in case you are producing an image
for an `ARM` target. Use [GoArm official](https://github.com/golang/go/wiki/GoArm) to
produce binaries that you copy to the final artifact.

More resources on how to produce [Golang static
binaries](https://docs.ionoid.io/docs/iot-apps.html#golang-static-binaries).


### Alpine Based File System

[Alpine](https://alpinelinux.org/) is a security-oriented, lightweight Linux distribution based on musl libc and busybox.
Using `mkiot` tools we can build Alpine based file system applications.

* Minimal Alpine file system for `armhf`:
```bash
sudo mkiot build examples/alpine/buildspec-minimal-alpine-armhf.yaml
```

* Development Alpine with more development packages:

TO BE ADDED

#### Node.js based on Alpine

* [Node.js
package](https://nodejs.org/) from Alpine distribution with minimal packages:
```bash
sudo mkiot build examples/node.js/alpine/buildspec-node.js_minimal_alpine_armhf.yaml
```

* [Node.js
package](https://nodejs.org/) from Alpine distribution with development packages:
```bash
sudo mkiot build examples/node.js/alpine/buildspec-node.js_build-base_alpine_armhf.yaml
```

* [Node-RED](https://nodered.org/) app example:
Please follow this example: [build Node-RED](examples/apps/node-red) and deploy it to your devices.


#### Golang based on Alpine

For Golang we recommend to use the same architecture of the host, in case you are producing an image
for an `ARM` target. Use [GoArm official](https://github.com/golang/go/wiki/GoArm) to
produce binaries that you copy to the final artifact.

More resources on how to produce [Golang static
binaries](https://docs.ionoid.io/docs/iot-apps.html#golang-static-binaries).


### Scratch File System

Scratch based file system contains empty directories parts of the [Filesystem Hierarchy
Standard](https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard). The directories are empty on purpose, which
allows to build images on top.

* Scratch file system example:

```bash
sudo mkiot build examples/scratch/buildspec.yaml
```


## Multi-Stage Builds

One of the main issues of IoT and Edge devices is storage size, deploying artifacts and images that contain the full
build environment with multiple libraries and packages that are necessary to build the application but not to run it,
makes this a noticeable and annoying problem that in IoT world can be a real challenge.

To solve this `mkiot` makes use of multi-stage builds, if you are familiar with `docker` this is somehow comparable to
[Docker multi-stage builds](https://docs.docker.com/develop/develop-images/multistage-build/). It allows to organize the
buildspec yaml file in different section in order to keep the image size small.

During `installs` phase, you can specify multiple images to install, one for the build process and another one for the
final production artifact. The production image will after copy the final binaries and packages that were produced from
the build image.

Using the [copy command](#build-spec-commands-documentation) and the `--from=image-name` will copy files and directories
from a different base image or from the image named `image-name` to the current working image. This allows to copy files
and directories between different images during all phases of the build process, assuming that images names are
correct.

Example of copying files between images:
```yaml
version: 0.1

arch: armhf
build-directory: output/

env:
        variables:
                key: "value"
                arch: "armhf"

phases:
        installs:
                # Download minimal debian image and name it
                # `debian-armhf-development`
                - image: debian
                  mirror: http://deb.debian.org/debian/
                  release: buster
                  name: debian-armhf-development
                  cache: "reuse"
                  commands:
                        - ["/bin/bash", "-c", "echo Installed debian buster arch $arch"]
                        - ["cat", "/etc/os-release"]
                        - ["echo", "OS release file output above"]

                # Download a secondary minimal debian image and name it
                # `debian-armhf-production`
                - image: debian
                  mirror: http://deb.debian.org/debian/
                  release: buster
                  name: debian-armhf-production

        # Build stages now
        builds:
                # Use debian-armhf-development image to build application
                - use: debian-armhf-development
                  commands:
                        # Install extra dependecies
                        - ["apt", "install", "-y", "$dependencies" ]

                        # Copy `config` file from local host file system into image
                        # named `debian-armhf-development` in /etc/ directory
                        - ["copy", "myapp/config", "/etc/config"]

                        # Build myapp
                        - ["build-myapp" ]


                # Use debian-armhf-production image as target
                - use: debian-armhf-production
                  commands:
                        # copy from image name `debian-armhf-development` file
                        # `/etc/config` into current in use image which is
                        # `debian-armhf-production` using same file location
                        - ["copy", "--from=debian-armhf-development", "/etc/config", "/etc/config"]


        post-builds:
                - use: debian-armhf-production
                  commands:
                        # See content of file copied from another image
                        - ["cat", "/etc/config"]
                        - ["echo", "Build production finished"]

artifacts:
        # Use the image named `debian-armhf-production` as base image for the final artifact
        - use: debian-armhf-production

          # Name of final artifact
          name: debian-buster-armhf

          # Files to copy to artifact
          files:
             - app.yaml  /app.yaml
             - myapp     /usr/bin/myapp

          # suffix artifact name with current date yy-mm-day
          suffix: date +%Y-%m-%d
          compression: tar

```
