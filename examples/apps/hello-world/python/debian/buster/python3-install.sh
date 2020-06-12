#!/bin/sh

apt update && apt install -y python3 python3-pip \
  && python3 --version
