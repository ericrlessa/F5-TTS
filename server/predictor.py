# This is the file that implements a flask server to do inferences. It's the file that you will modify to
# implement the scoring for your own algorithm.

from __future__ import print_function

import os
import time
import sys

import boto3

import json

import flask
import subprocess
import uuid

import tempfile

# The flask app for serving predictions
app = flask.Flask(__name__)

s3 = boto3.client("s3", region_name="us-east-1")

def download_s3_file(bucket, key, local_path):
    with open(local_path, "wb") as f:
        s3.download_fileobj(bucket, key, f)
    return local_path

@app.route("/ping", methods=["GET"])
def ping():
    """Determine if the container is working and healthy. In this sample container, we declare
    it healthy if we can load the model successfully."""
#    health = ScoringService.get_model() is not None  # You can insert a health check here

 #   status = 200 if health else 404
    return flask.Response(response="\n", status=200, mimetype="application/json")

@app.route("/invocations", methods=["POST"])
def inference():
    with tempfile.TemporaryDirectory() as temp_dir:
        
        output_filename = f"{uuid.uuid4().hex}.wav"
        output_path = os.path.join(temp_dir, output_filename)

        if flask.request.is_json:
            data = flask.request.get_json()

            required_keys = ["bucket", "s3_key_gen", "voices", "s3_key_output"]
            if not all(k in data for k in required_keys):
                return flask.jsonify({"error": "Missing required fields"}), 400

            try:
                
                bucket  =  data.get("bucket")
                gen_key =  data.get("s3_key_gen")
                voices  =  data.get("voices")
                s3_key_output = data.get("s3_key_output")
                
                cmd = json_inference(temp_dir, output_filename, bucket, gen_key, voices)
                
                call_process(cmd)

                with open(output_path, "rb") as f:
                    s3.put_object(
                        Bucket=bucket,
                        Key=s3_key_output,
                        Body=f,
                        ContentType="audio/wav"
                    )
                
                print(f"✅ Podcast stored in {s3_key_output}")

            except Exception as e:
                print("Error:", str(e), file=sys.stderr)
                return flask.jsonify({"error": "Inference failed"}), 500
        else:
            return flask.jsonify({"error": "Content should be json"}), 400

        return flask.jsonify({"status": "ok"}), 200

def call_process(cmd):
    try:
        start_time = time.time()
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        elapsed = time.time() - start_time
        print(f"⏱ Inference took {elapsed:.2f} seconds", file=sys.stdout, flush=True)
        print("Subprocess output:", result.stdout, flush=True)
    except subprocess.CalledProcessError as e:
        raise e

def json_inference(temp_dir, output_filename, bucket, gen_key, voices):
    config_file = create_toml_file(temp_dir, output_filename, bucket, gen_key, voices)
    print(f"Config toml file: \n{config_file}")
    config_file_path = os.path.join(temp_dir, "config_file.toml")
    with open(config_file_path, "w") as f:
        f.write(config_file)

    return ["f5-tts_infer-cli", "--config", config_file_path]

def create_toml_file(temp_dir, output_filename, bucket, gen_key, voices):
    input_path = os.path.join(temp_dir, "gen_file.txt")
    gen_key_local_path = download_s3_file(bucket, gen_key, input_path)

    config_file = 'model = "F5TTS_v1_Base"\n'
    config_file += f'gen_file = "{gen_key_local_path}"\n'
    config_file += 'remove_silence = true\n'
    config_file += f'output_dir = "{temp_dir}"\n'
    config_file += f'output_file = "{output_filename}"\n'

    for voice in voices:
        config_file += f"[voices.{voice['name']}]\n"
        ref_audio_path = download_s3_file(bucket, voice["s3_key_ref_audio"], os.path.join(temp_dir, f"{uuid.uuid4().hex}.wav"))
        config_file += f'ref_audio = "{ref_audio_path}"\n'
        ref_text_path = download_s3_file(bucket, voice["s3_key_ref_text"], os.path.join(temp_dir, f"{uuid.uuid4().hex}.txt"))
        config_file += f'ref_text = "{ref_text_path}"\n'

    return config_file