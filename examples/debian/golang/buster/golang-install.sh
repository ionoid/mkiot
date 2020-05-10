#!/bin/sh

url="https://golang.org/dl/go${GOLANG_VERSION}.${OS}-${GOLANG_ARCH}.tar.gz"

# remove old go in case
rm -fr /usr/local/go
rm -f /usr/local/bin/go
rm -f /usr/local/bin/gofmt

wget -O go.tgz "$url"
tar -C /usr/local -xzf go.tgz
rm go.tgz

export PATH="/usr/local/go/bin:$PATH"

# Lets creat go links in /usr/local/bin/ to make it easy for developers
cpwd=$(pwd)
cd /usr/local/bin/
ln -sr ../go/bin/go go > /dev/null 2>&1
ln -sr ../go/bin/gofmt gofmt > /dev/null 2>&1
cd $cpwd

go version

mkdir -p "${GOPATH}"
mkdir -p "${GOPATH}/src"
mkdir -p "${GOPATH}/bin"
chmod -R 755 "${GOPATH}"
