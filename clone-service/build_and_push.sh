#!/usr/bin/env bash

region=$1
region=${region:-us-east-1}

image=${image:-lambda-voice-clone}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash ${SCRIPT_DIR}/../build_and_push.sh ${region} ${image} ${SCRIPT_DIR}