FROM nvidia/cuda:12.4-runtime-ubuntu22.04

USER root

ARG DEBIAN_FRONTEND=noninteractive

RUN set -x \
    && apt-get update \
    && apt-get -y install wget curl man git less openssl libssl-dev unzip unar build-essential aria2 tmux vim \
    && apt-get install -y openssh-server sox libsox-fmt-all libsox-fmt-mp3 libsndfile1-dev ffmpeg \
    && apt-get install -y librdmacm1 libibumad3 librdmacm-dev libibverbs1 libibverbs-dev ibverbs-utils ibverbs-providers \
    && apt-get install -y nginx ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

RUN pip3 install --no-cache-dir torch torchaudio --index-url https://download.pytorch.org/whl/cu124

COPY ./ /workspace/F5-TTS

RUN chmod +x /workspace/F5-TTS/sqs-listener/serve
    
WORKDIR /workspace/F5-TTS

RUN git submodule update --init --recursive \
    && pip install -e . --no-cache-dir \
    && pip install flask gunicorn

ENV SHELL=/bin/bash

VOLUME /root/.cache/huggingface/hub/

ENV PATH="/workspace/F5-TTS/sqs-listener:${PATH}"

WORKDIR /workspace/F5-TTS/sqs-listener

EXPOSE 8080

