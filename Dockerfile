# Stage 1: Build stage
FROM pytorch/pytorch:2.4.0-cuda12.4-cudnn9-devel AS builder

USER root
ARG DEBIAN_FRONTEND=noninteractive

# Install only essential build dependencies
RUN apt-get update && \
    apt-get -y install --no-install-recommends \
        git \
        build-essential \
        libssl-dev \
        sox \
        libsox-fmt-all \
        libsndfile1-dev \
        ffmpeg && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

COPY ./ /workspace/F5-TTS

WORKDIR /workspace/F5-TTS

RUN git submodule update --init --recursive && \
    pip install --no-cache-dir -e .

# Stage 2: Runtime stage - FRESH INSTALL
FROM pytorch/pytorch:2.4.0-cuda12.4-cudnn9-runtime

USER root
ARG DEBIAN_FRONTEND=noninteractive

# Install only runtime dependencies
RUN apt-get update && \
    apt-get -y install --no-install-recommends \
        wget \
        curl \
        git \
        openssl \
        libssl-dev \
        sox \
        libsox-fmt-all \
        libsox-fmt-mp3 \
        libsndfile1-dev \
        ffmpeg \
        librdmacm1 \
        libibumad3 \
        libibverbs1 && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy ONLY your source code, NOT the conda environment
COPY --from=builder /workspace/F5-TTS /workspace/F5-TTS

RUN chmod +x /workspace/F5-TTS/sqs-listener/serve

WORKDIR /workspace/F5-TTS

# Reinstall your package and dependencies in the clean runtime environment
RUN pip install --no-cache-dir -e . flask

ENV SHELL=/bin/bash
VOLUME /root/.cache/huggingface/hub/
ENV PATH="/workspace/F5-TTS/sqs-listener:${PATH}"
WORKDIR /workspace/F5-TTS/sqs-listener
EXPOSE 8080