# Ionoid.io Images and buildspec examples



## Build spec syntax


## Images naming

Taking example of a golang environment, final image should be named:

* Debian based golang version 1.14 images:
```
        golang-1.14_debian-buster_386
        golang-1.14_debian-buster_amd64
        golang-1.14_debian-buster_armhf
        golang-1.14_debian-buster_arm64

        golang-latest_$arch     /* points to one of the above */
```
