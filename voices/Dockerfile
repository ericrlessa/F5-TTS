FROM public.ecr.aws/lambda/python:3.12

RUN dnf install -y tar xz && dnf clean all

RUN curl -L -o /tmp/ffmpeg-release-amd64-static.tar.xz https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz \
    && tar -xf /tmp/ffmpeg-release-amd64-static.tar.xz -C /tmp \
    && cp /tmp/ffmpeg-*-amd64-static/ffmpeg /usr/local/bin/ffmpeg \
    && cp /tmp/ffmpeg-*-amd64-static/ffprobe /usr/local/bin/ffprobe \
    && chmod +x /usr/local/bin/ffmpeg /usr/local/bin/ffprobe \
    && rm -rf /tmp/ffmpeg-*-amd64-static /tmp/ffmpeg-release-amd64-static.tar.xz

RUN ffmpeg -version && ffprobe -version

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app.py .

CMD ["app.handler"]