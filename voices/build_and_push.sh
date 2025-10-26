#!/usr/bin/env bash

region=$1
region=${region:-ca-central-1}

image=${image:-voices}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash ${SCRIPT_DIR}/../build_and_push.sh ${region} ${image} ${SCRIPT_DIR}