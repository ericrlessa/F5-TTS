# Stage 1: Build stage
FROM pytorch/pytorch:2.4.0-cuda12.4-cudnn9-devel as builder

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

# Stage 2: Runtime stage
FROM pytorch/pytorch:2.4.0-cuda12.4-cudnn9-runtime

USER root
ARG DEBIAN_FRONTEND=noninteractive

# Install only runtime dependencies (no build tools, nginx, or gunicorn)
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
    # Remove unnecessary packages to save space
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy installed application from builder stage
COPY --from=builder /workspace/F5-TTS /workspace/F5-TTS
COPY --from=builder /opt/conda /opt/conda

RUN chmod +x /workspace/F5-TTS/sqs-listener/serve

WORKDIR /workspace/F5-TTS

# Install only Flask (no gunicorn)
RUN pip install --no-cache-dir flask

ENV SHELL=/bin/bash
VOLUME /root/.cache/huggingface/hub/
ENV PATH="/workspace/F5-TTS/sqs-listener:${PATH}"
WORKDIR /workspace/F5-TTS/sqs-listener
EXPOSE 8080

# ENTRYPOINT ["f5-tts_infer-cli", "--model", "F5TTS_v1_Base", \
#      "--ref_audio", "/opt/ml/input/data/input/ref.wav", \
#      "--ref_text", "Some call me nature, others call me mother nature.",  \
#      "--gen_file", "/opt/ml/input/data/input/gen.txt", \
#      "--output_dir", "/opt/ml/output"]