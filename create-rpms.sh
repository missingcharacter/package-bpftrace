#!/usr/bin/env bash
set -eEu -o pipefail
shopt -s extdebug
IFS=$'\n\t'

docker run -v ${PWD}:/mnt --workdir=/mnt --rm -it amazonlinux:2018.03.0.20191014.0-with-sources bash -x build.sh
