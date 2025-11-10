#!/usr/bin/env bash

region=$1
region=${region:-ca-central-1}

env=$2
env=${env:-dev}

bash ./podcast-episodes/build_and_push.sh ${region} ${env}

bash ./processing-result-listener/build_and_push.sh ${region} ${env}

bash ./scraper/build_and_push.sh ${region} ${env}

bash ./voices/build_and_push.sh ${region} ${env}