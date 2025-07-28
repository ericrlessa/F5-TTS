#!/usr/bin/env bash

region=$1
region=${region:-ca-central-1}

bash ./clone-service/build_and_push.sh ${region}

bash ./generate-audio/build_and_push.sh ${region}

bash ./list-audio/build_and_push.sh ${region}

bash ./sqs-listener/build_and_push.sh ${region}