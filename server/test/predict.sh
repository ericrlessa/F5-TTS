#!/bin/bash

#payload=$1
#content=${2:-text/csv}

#curl --data-binary @${payload} -H "Content-Type: ${content}" -v http://localhost:8080/invocations

curl -X POST http://localhost:8080/invocations \
  -F "audio=@../../src/f5_tts/infer/examples/basic/basic_ref_en.wav" \
  -F "text=Hello World." \
  -F "ref_text=Some call me nature, others call me mother nature."
