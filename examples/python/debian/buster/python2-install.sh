#!/bin/sh

apt update && apt install -y python python-pip \
  && python --version
