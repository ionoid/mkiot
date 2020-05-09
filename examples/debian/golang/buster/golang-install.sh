#!/bin/sh

url="https://golang.org/dl/go${GOLANG_VERSION}.${OS}-${GOLANG_ARCH}.tar.gz"

# remove old go in case
rm -fr /usr/local/go

wget -O go.tgz "$url"
tar -C /usr/local -xzf go.tgz
rm go.tgz
export PATH="/usr/local/go/bin:$PATH"; \
go version

mkdir -p "${GOPATH}"
echo "export PATH=$PATH:/usr/local/go/bin" > /etc/profile.d/gopath.sh
echo "export GOPATH=${GOPATH}" >> /etc/profile.d/gopath.sh

mkdir -p "$GOPATH/src"
mkdir -p "$GOPATH/bin"
chmod -R 755 "$GOPATH"
